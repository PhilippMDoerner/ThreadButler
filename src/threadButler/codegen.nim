import std/[macros, tables, strformat, strutils, unicode, sequtils]
import ./utils
import ./register
import ./channelHub

##[ .. importdoc::  channelHub.nim
Defines all code for code generation in threadbutler.
All names of generated types are inferred from the name they are being registered with.
All names of fields and enum kinds are inferred based on the data registered.

.. note:: Only the macros provided here are for general use. The procs are only for writing new integrations.

]##
# Cleanup TODO:
# 1) Doc Comments on everything
# 2) Package tests maybe?
# 3) README.md
proc variantName*(name: ThreadName): string = 
  ## Infers the name of the Message-object-variant-type associated with `name` from `name`
  name.string.capitalize() & "Message"

proc enumName*(name: ThreadName): string = 
  ## Infers the name of the enum-type associated with `name` from `name`
  name.string.capitalize() & "Kinds"

proc firstParamName*(node: NimNode): string =
  ## Extracts the name of the first parameter of a proc
  node.assertKind(@[nnkProcDef])
  let firstParam = node.params[1]
  firstParam.assertKind(nnkIdentDefs)
  return $firstParam[0]
  
proc kindName*(node: NimNode): string =
  ## Infers the name of a kind of an enum from a type
  node.assertKind(@[nnkTypeDef])
  let typeName = node.typeName
  return capitalize(typeName) & "Kind"

proc killKindName*(name: ThreadName): string =
  ## Infers the name of the enum-kind for a message that kills the thread
  ## associated with `name` from `name`.
  "Kill" & name.string.capitalize() & "Kind"

proc fieldName*(node: NimNode): string =
  ## Infers the name of a field on a Message-object-variant-type from a type
  node.assertKind(@[nnkTypeDef])
  let typeName = node.typeName()
  return normalize(typeName) & "Msg"

proc extractProcDefs(node: NimNode): seq[NimNode] =
  ## Extracts nnkProcDef-NimNodes from a given node.
  ## Does not extract all nnkProcDef-NimNodes, only those that were added using supported Syntax.
  ## For the supported syntax constellations see `registerRouteFor`_
  node.assertKind(@[nnkProcDef, nnkSym, nnkStmtList])
  
  case node.kind:
  of nnkProcDef:
    result.add(node)
  of nnkSym: 
    let procDef = node.getImpl()
    procDef.assertKind(nnkProcDef)
    result.add(procDef)
    
  of nnkStmtList:
    for subNode in node:
      case subNode.kind:
      of nnkProcDef:
        result.add(subNode)
      else:
        error(fmt"Defining non-proc nodes of kind '{subNode.kind}' in section for proc definitions is not supported!")
    
  else: 
    discard

proc toThreadName*(node: NimNode): ThreadName =
  ## Extracts ThreadName from NimNode.
  ## Supports node being either a string literal or a const variable of a string.
  node.assertKind(@[nnkStrLit, nnkSym])
  
  case node.kind:
  of nnkStrLit: 
    let name = $node
    return ThreadName(name)
  
  of nnkSym: 
    let constExpression: NimNode = node.getImpl()
    let valueNode: NimNode = constExpression[2]
    valueNode.assertKind(nnkStrLit)
    let value: string = $valueNode
    return ThreadName(value)
  
  else:
    error("Unsupported way of declaring a ThreadName: " & $node.kind)
  
  
macro registerRouteFor*(name: string, input: typed) =
  ## Registers a handler proc for `name` with threadButler.
  ## Supports usage in various syntax-constellations:
  ## ```
  ## 1) registerRouteFor(myProc)
  ## 2) registerRouteFor():
  ##      proc myProc1() = <myProc1Implementation>
  ##      proc myProc2() = <myProc2Implementation>
  ## 3) proc myProc() {.registerRouteFor.} = <myProcImplementation>
  ## ```
  ## This does not change or remove any proc definitions this macro is applied to.
  ## Registered procs are used for code-generation with various macros, e.g. `generate`. 
  ## This does not generate code on its own.
  input.expectKind(
    @[nnkProcDef, nnkSym, nnkStmtList], 
    fmt"""
      Tried to register `{strutils.strip(input.repr)}` as serverRoute with unsupported syntax!
      The following are supported:
        - proc myProc(msg: SomeType, hub: ChannelHub){"\{.registerRouteFor\: \"<someName>\".\}"} = <Your Implementation>
        - registerRouteFor("<someName>", myProc)
        - registerRouteFor("<someName>"):
          proc myProc(msg: SomeType, hub: ChannelHub) = <Your Implementation>
    """.dedent(6)
  )
  let name: ThreadName = name.toThreadName()
  
  let procDefs = input.extractProcDefs() 
  for procDef in procDefs:
    name.addRoute(procDef)
  
  let containsProcDefs = input.kind in [nnkProcDef, nnkStmtList]
  if containsProcDefs:
    result = input ## Necessary so that the defined proc does not "disappear"

  when defined(butlerDebug):
    let procNames = procDefs.mapIt($it.name)
    echo fmt"Registered handlers '{procNames}' for '{name.string}'"


proc extractTypeDefs(node: NimNode): seq[NimNode] =
  ## Extracts nnkTypeDef-NimNodes from a given node.
  ## Does not extract all nnkTypeDef-NimNodes, only those that were added using supported Syntax.
  ## For the supported syntax constellations see `registerTypeFor`_
  node.assertKind(@[nnkTypeDef, nnkSym, nnkStmtList])

  case node.kind:
  of nnkTypeDef:
    result.add(node)
  of nnkSym:
    let typeDef = node.getImpl()
    typeDef.assertKind(nnkTypeDef)
    result.add(typeDef)
    
  of nnkStmtList:
    for subNode in node:
      case subNode.kind:
      of nnkTypeDef:
        result.add(subNode)
        
      of nnkTypeSection:
        for subSubNode in subNode:
          subSubNode.assertKind(nnkTypeDef)
          result.add(subSubNode)
          
      else:
        error(fmt"Inner node of kind '{subNode.kind}' is not supported!")
  else:
    error(fmt"Node of kind '{node.kind}' not supported!")
  

macro registerTypeFor*(name: string, input: typed) =
  ## Registers a type of a message for `name` with threadButler.
  ## This does not change or remove any type definition this macro is applied to.
  ## Supported syntax variations are:
  ## ```
  ## 1) registerTypeFor(myType)
  ## 2) registerTypeFor():
  ##      type myType1 = <myTypeDef1>
  ## 3) registerTypeFor():
  ##      type 
  ##        myType1 = <myTypeDef1>
  ##        myType2 = <myTypeDef2>  
  ## ```
  ## Registered types are used for code-generation with various macros, e.g. `generate`.
  ## This does not generate code on its own.
  input.expectKind(
    @[nnkSym, nnkStmtList], 
    fmt"""
      Tried to register `{strutils.strip(input.repr)}` as type with unsupported syntax!
      The following are supported:
        - registerTypeFor("someName", SomeType)
        - registerTypeFor("someName"):
            type SomeType = <Your Type declaration>
        - registerTypeFor("someName"):
            type 
              OtherType = <Second Type declaration>
              ThirdType = <Third Type declaration>
    """.dedent(6)
  )
  let name: ThreadName = name.toThreadName()
    
  for typeDef in input.extractTypeDefs():
    name.addType(typeDef)
  
  let containsTypeDefs = input.kind in [nnkTypeDef, nnkTypeSection, nnkStmtList]
  if containsTypeDefs: 
    result = input  ## Necessary so that the defined type does not "disappear"

  when defined(butlerDebug):
    let typeNames = input.extractTypeDefs().mapIt($it[0])
    echo fmt"Registered types '{typeNames}' for '{name.string}'"

proc asEnum(name: ThreadName, types: seq[NimNode]): NimNode =
  ## Generates an enum type for `name`.
  ## It has one kind per type in `types` + a "killKind".
  ## The name of the 'killKind' is inferred from `name`, see the proc `killKindName`_.
  ## The name of the enum-type is inferred from `name`, see the proc `enumName`_.
  ## The name of the individual other enum-kinds is inferred from the various typeNames, see the proc `kindName`_.
  ## The enum is generated according to the pattern:
  ## ```
  ##  type <name>Kinds = enum
  ##    --- Repeat per type - start ---
  ##    <typeKind>
  ##    --- Repeat per type - end ---
  ##    <killKind>
  ## ```
  var enumFields: seq[NimNode] = types.mapIt(ident(it.kindName))
  let killThreadKind = ident(name.killKindName)
  enumFields.add(killThreadKind)
  
  return newEnum(
    name = ident(name.enumName), 
    fields = enumFields, 
    public = true,
    pure = true
  )

proc asVariant(name: ThreadName, types: seq[NimNode] ): NimNode =
  ## Generates a ref object variant type for `name`.
  ## The variantName is inferred from `name`, see the proc `variantName`_.
  ## The name of the killKind is inferred from `name`, see the proc `killKindName`_.
  ## The name of msgField is inferred from `type`, see the proc `fieldName`_.
  ## Uses the enum-type generated by `asEnum`_ for the discriminator.
  ## The variant is generated according to the pattern:
  ## ```
  ##  type <variantName> = ref object
  ##    case kind*: <enumName>
  ##    --- Repeat per type - start ---
  ##    of <enumKind>: 
  ##      <msgField>: <type>
  ##    --- Repeat per type - end ---
  ##    of <killKind>: discard
  ## ```
  let hasTypes = types.len() > 0
  if not hasTypes:
    let typeName = postfix(newIdentNode(name.variantName), "*")
    return quote do:
      type `typeName` = ref object 
  # Generates: case kind*: <enumName>
  let caseNode = nnkRecCase.newTree(
    nnkIdentDefs.newTree(
      postfix(newIdentNode("kind"), "*"),
      newIdentNode(name.enumName),
      newEmptyNode()
    )
  )
  
  for typ in name.getTypes():
    # Generates: of <enumKind>: <msgField>: <typ>
    typ.assertKind(nnkTypeDef)
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(typ.kindName),
      nnkRecList.newTree(
        newIdentDefs(
          postfix(newIdentNode(typ.fieldName), "*"),
          ident(typ.typeName)
        ) 
      )
    )
    
    caseNode.add(branchNode)
  
  # Generates: of <killKind>: discard
  let killBranchNode = nnkOfBranch.newTree(
    newIdentNode(name.killKindName),
    nnkRecList.newTree(newNilLit())
  )
  caseNode.add(killBranchNode)
  
  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      postfix(newIdentNode(name.variantName), "*"),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree( caseNode )
      )
    )
  )
  
proc genMessageRouter*(name: ThreadName, routes: seq[NimNode], types: seq[NimNode]): NimNode =
  ## Generates a proc `routeMessage` for unpacking the object variant type for `name` and calling a handler proc with the unpacked value.
  ## The variantTypeName is inferred from `name`, see the proc `variantName`_.
  ## The name of the killKind is inferred from `name`, see the proc `killKindName`_.
  ## The name of msgField is inferred from `type`, see the proc `fieldName`_.
  ## The proc is generated based on the registered routes according to this pattern:
  ## ```
  ##  proc routeMessage\*(msg: <variantTypeName>, hub: ChannelHub) =
  ##    case msg.kind:
  ##    --- Repeat per route - start ---
  ##    of <enumKind>:
  ##      <handlerProc>(msg.<msgField>, hub)
  ##    --- Repeat per route - end ---
  ##    of <killKind>: shutDownServer()
  ## ```
  ## This proc should only be used by macros in this and other integration modules.
  result = newProc(name = postfix(ident("routeMessage"), "*"))
  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(name.variantName))
  result.params.add(msgParam)
  
  let hubParam = newIdentDefs(
    ident("hub"), 
    ident("ChannelHub")
  )
  result.params.add(hubParam)
  
  let hasEmptyMessageVariant = not types.len() == 0
  if hasEmptyMessageVariant:
    result.body = nnkDiscardStmt.newTree(newEmptyNode())
    return
  
  let caseStmt = nnkCaseStmt.newTree(
    newDotExpr(ident(msgParamName), ident("kind"))
  )
  
  for handlerProc in routes:
    # Generates proc call `<routeName>(<msgParamName>.<fieldName>, hub)`
    let firstParamType = handlerProc.firstParamType
    let handlerCall = nnkCall.newTree(
      handlerProc.name,
      newDotExpr(ident(msgParamName), ident(firstParamType.fieldName)),
      ident("hub")
    )
    
    # Generates `of <enumKind>: <handlerCall>`
    let branchNode = nnkOfBranch.newTree(
      ident(firstParamType.kindName),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
  
  # Generates `of <killKind>: shutdownServer()`: 
  let killBranchNode = nnkOfBranch.newTree(
    ident(name.killKindName),
    nnkCall.newTree(ident("shutdownServer"))
  )
  caseStmt.add(killBranchNode)
  
  result.body.add(caseStmt)

proc genSenderProc(name: ThreadName, typ: NimNode): NimNode =
  ## Generates a generic proc `sendMessage`.
  ## These procs can be used by any thread to send messages to thread `name`.
  ## They "wrap" the message of type `typ` in the object-variant generated by 
  ## `asVariant` before sending that message through the corresponding `Channel`.
  typ.assertKind(nnkTypeDef)
  
  let procName = newIdentNode("sendMessage")
  let msgType = newIdentNode(typ.typeName)
  let variantType = newIdentNode(name.variantName)
  let msgKind = newIdentNode(typ.kindName)
  let variantField = newIdentNode(typ.fieldName)
  let senderProcName = newIdentNode(channelHub.SEND_PROC_NAME) # This string depends on the name 
  
  quote do:
    proc `procName`*(hub: ChannelHub, msg: `msgType`): bool =
      let msgWrapper: `variantType` = `variantType`(kind: `msgKind`, `variantField`: msg)
      return hub.`senderProcName`(msgWrapper)

proc genNewChannelHubProc*(): NimNode =
  ## Generates a proc `new` for instantiating a ChannelHub
  ## with a channel to send messages to each thread.
  ## Uses `addChannel`_ to instantiate, open and add a channel.
  ## Uses `variantName`_ to infer the name Message-object-variant-type.
  ## The proc is generated based on the registered threadnames according to this pattern:
  ## ```
  ##  proc new\*(t: typedesc[ChannelHub]): ChannelHub =
  ##    result = ChannelHub(channels: initTable[pointer, pointer]())
  ##    --- Repeat per threadname - start ---
  ##    result.addChannel(<variantName>)
  ##    --- Repeat per threadname - end ---
  ## ```
  result = quote do:
    proc new*(t: typedesc[ChannelHub]): ChannelHub =
      result = ChannelHub(channels: initTable[pointer, pointer]())
  
  for threadName in getRegisteredThreadnames():
    let variantType = newIdentNode(threadName.variantName)
    let addChannelLine = quote do:
      result.addChannel(`variantType`)
    result.body.add(addChannelLine)

proc genDestroyChannelHubProc*(): NimNode =
  ## Generates a proc `destroy` for destroying a ChannelHub.
  ## Closes each channel stored in the hub as part of that.
  ## Uses `variantName`_ to infer the name Message-object-variant-type.
  ## The proc is generated based on the registered threadnames according to this pattern:
  ## ```
  ##  proc destroy\*(hub: ChannelHub) =
  ##    --- Repeat per threadname - start ---
  ##    hub.getChannel(<variantName>).close()
  ##    --- Repeat per threadname - end ---
  ## ```
  let hubParam = newIdentNode("hub")
  result = quote do:
    proc destroy*(`hubParam`: ChannelHub) =
      notice "Destroying Channelhub"
  
  for threadName in getRegisteredThreadnames():
    let variantType = newIdentNode(threadName.variantName)
    let closeChannelLine = quote do:
      `hubParam`.getChannel(`variantType`).close()
    
    result.body.add(closeChannelLine)

proc genSendKillMessageProc*(name: ThreadName): NimNode =
  ## Generates a proc `sendKillMessage`
  ## These procs send a message that triggers the graceful shutdown of a thread.
  ## The thread to send the message to is inferred based on the object-variant for messages to that thread.
  ## The name of the object-variant is inferred from `name` via `variantName`_.
  let variantType = newIdentNode(name.variantName)
  let killKind = newIdentNode(name.killKindName)
  let senderProcName = newIdentNode(channelHub.SEND_PROC_NAME) # This string depends on the name 

  result = quote do:
    proc sendKillMessage*(hub: ChannelHub, msg: typedesc[`variantType`]) =
      let killMsg = `variantType`(kind: `killKind`)
      discard hub.`senderProcName`(killMsg)

proc generateCode*(name: ThreadName): NimNode =
  ## Generates all types and procs needed for message-passing for `name`.
  ## This proc should only be used by macros in this and other integration modules.

  result = newStmtList()
  
  let types = name.getTypes()
  
  let messageEnum = name.asEnum(types)
  result.add(messageEnum)
  
  let messageVariant = name.asVariant(types)
  result.add(messageVariant)
  
  for typ in name.getTypes():
    result.add(genSenderProc(name, typ))

  let killThreadProc = name.genSendKillMessageProc()
  result.add(killThreadProc)

macro generateSetupCode*() =
  ## Generates all types and procs needed for message-passing for `name`:
  ## 1) An enum based representing all different types of messages that can be sent to the thread `name`.
  ## 2) An object variant that wraps any message to be sent through a channel to the thread `name`.
  ## 3) Generic `sendMessage` procs for sending messages to `name` by:
  ##      - receiving a message-type
  ##      - wrapping it in the object variant from 2)
  ##      - sending that to a channel to the thread `name`.
  ## 4) Specific `sendKillMessage` procs for sending a "kill" message to `name`
  ## 5) A `new(ChannelHub)` proc to instantiate a ChannelHub
  ## 6) A `destroy` proc to destroy a ChannelHub
  ## 
  ## Note, this does not include a proc for routing. See `generateRouters`_
  result = newStmtList()
  for threadName in getRegisteredThreadnames():
    for node in threadName.generateCode():
      result.add(node)
  
  result.add(genNewChannelHubProc())
  result.add(genDestroyChannelHubProc())
  
  when defined(butlerDebug):
    echo result.repr
    
macro generateRouters*() =
  ## Generates a routing proc for every registered thread.
  ## See `genMessageRouter`_ for specifics.
  result = newStmtList()
  
  for threadName in getRegisteredThreadnames():
    let routingProc = threadName.genMessageRouter(threadName.getRoutes(), threadName.getTypes())
    result.add(routingProc)
        
  when defined(butlerDebug):
    echo result.repr