import std/[macros, tables, genasts, strformat, sets, strutils, unicode, sequtils]
import ./utils
import ./register
import ./channelHub
import ./validation
import ./types

export utils

##[ .. importdoc::  channelHub.nim
Defines all code for code generation in threadbutler.
All names of generated types are inferred from the name they are being registered with.
All names of fields and enum kinds are inferred based on the data registered.

.. note:: Only the macros are for general users. The procs are only for writing new integrations.

]##
proc variantName*(name: ThreadName): string = 
  ## Infers the name of the Message-object-variant-type associated with `name` from `name`
  name.string.capitalize() & "Message"

proc threadVariableName*(name: ThreadName): string =
  ## Infers the name of the variable containing the Thread that runs the server from `name`
  name.string.toLower() & "ButlerThread"

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
  node.assertKind(@[nnkIdent])
  let typeName = node.typeName
  return capitalize(typeName) & "Kind"

proc killKindName*(name: ThreadName): string =
  ## Infers the name of the enum-kind for a message that kills the thread
  ## associated with `name` from `name`.
  "Kill" & name.string.capitalize() & "Kind"

proc fieldName*(node: NimNode): string =
  ## Infers the name of a field on a Message-object-variant-type from a type
  node.assertKind(@[nnkIdent])
  let typeName = node.typeName()
  return normalize(typeName) & "Msg"

proc signalName*(name: ThreadName): string =
  ## Infers the name of the thread-signal used to wake up the thread from
  ## sleeping
  name.string.toLower() & "Signal"

macro toThreadVariable*(name: static string): untyped =
  ## Generates the identifier for the global variable containing the thread for
  ## `name`.
  let varName = name.ThreadName.threadVariableName()
  return varName.ident()

macro toVariantType*(name: static string): untyped =
  ## Generate the typedesc identifier for the message-wrapper-type
  let variantName = name.ThreadName.variantName()
  return newIdentNode(variantName)

proc extractTypeDefs(node: NimNode): seq[NimNode] =
  ## Extracts nnkTypeDef-NimNodes from a given node.
  ## Does not extract all nnkTypeDef-NimNodes, only those that were added using supported Syntax.
  ## For the supported syntax constellations see `registerTypeFor`_
  node.assertKind(@[nnkTypeDef, nnkSym, nnkStmtList, nnkTypeSection])

  case node.kind:
  of nnkTypeDef:
    result.add(node)
    
  of nnkSym:
    let typeDef = node.getImpl()
    typeDef.assertKind(nnkTypeDef)
    result.add(typeDef)
    
  of nnkStmtList, nnkTypeSection:
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
  ## Generates a object variant type for `name`.
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
    typ.assertKind(nnkIdent)
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
      nnkRefTy.newTree(
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          nnkRecList.newTree( caseNode )
        ) 
      )
    )
  )

proc asThreadVar*(name: ThreadName): NimNode =
  ## Generates a global variable containing the thread for `name`:
  ## 
  ## `var <name>ButlerThread*: Thread[Server[<name>Message]]`
  let variableName = name.threadVariableName().ident()
  let variantName = name.variantName().ident()
  
  return quote do:
    var `variableName`*: Thread[Server[`variantName`]]

proc asSignalVar*(name: ThreadName): NimNode =
  ## Generates a global variable containing the signal for `name`:
  ## 
  ## `var <name>Signal*: ThreadSignalPtr
  let variableName = name.signalName().ident()
  
  return quote do:
    var `variableName`* = new(ThreadSignalPtr)[]

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
  ##      <handlerProc>(msg.<msgField>, hub) # if sync handlerProc
  ##      asyncSpawn <handlerProc>(msg.<msgField>, hub) # if async handlerProc
  ##    --- Repeat per route - end ---
  ##    of <killKind>: shutDownServer()
  ## ```
  ## This proc should only be used by macros in this and other integration modules.
  result = newProc(name = postfix(ident("routeMessage"), "*"))
  let msgParamName = "msg"
  let msgParam = newIdentDefs(
    ident(msgParamName), 
    nnkCommand.newTree(
      ident("sink"),
      ident(name.variantName)
    )
  )
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
    var handlerCall = nnkCall.newTree(
      handlerProc.name,
      newDotExpr(ident(msgParamName), ident(firstParamType.fieldName)),
      ident("hub")
    )
    
    # Generates `of <enumKind>: <handlerCall>`
    let branchStatements = if handlerProc.isAsyncProc():
        newStmtList(newCall("asyncSpawn".ident, handlerCall))
      else:
        newStmtList(handlerCall)
    let branchNode = nnkOfBranch.newTree(
      ident(firstParamType.kindName),
      branchStatements
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
  ## 
  ## These procs can be used by any thread to send messages to thread `name`.
  ## They "wrap" the message of type `typ` in the object-variant generated by 
  ## `asVariant` before sending that message through the corresponding `Channel`.
  typ.assertKind(nnkIdent)
  
  let procName = newIdentNode("sendMessage")
  let msgType = newIdentNode(typ.typeName)
  let variantType = newIdentNode(name.variantName)
  let msgKind = newIdentNode(typ.kindName)
  let variantField = newIdentNode(typ.fieldName)
  let senderProcName = newIdentNode(channelHub.SEND_PROC_NAME) # This string depends on the name 
  let serverSignal = newIdentNode(name.signalName())
  let threadName = newStrLitNode(name.string)
  
  genAst(procName, msgType, senderProcName, variantType, msgKind, variantField, serverSignal, threadName):
    proc procName*(hub: ChannelHub, msg: sink msgType): bool =
      let hasSentMessage: bool =  hub.senderProcName(variantType(kind: msgKind, `variantField`: move(msg)))
      
      if hasSentMessage:
        let response = serverSignal.fireSync()
        let hasSentSignal = response.isOk()
        if not hasSentSignal:
          notice "Failed to wake up threadServer " & threadName
      
      return hasSentMessage

proc genNewChannelHubProc*(): NimNode =
  ## Generates a proc `new` for instantiating a ChannelHub
  ## with a channel to send messages to each thread.
  ## 
  ## Uses `addChannel`_ to instantiate, open and add a channel.
  ## Uses `variantName`_ to infer the name Message-object-variant-type.
  ## The proc is generated based on the registered threadnames according to this pattern:
  ## ```
  ##  proc new\*(t: typedesc[ChannelHub], capacity: int = 500): ChannelHub =
  ##    result = ChannelHub(channels: initTable[pointer, pointer]())
  ##    --- Repeat per threadname - start ---
  ##    result.addChannel(<variantName>)
  ##    --- Repeat per threadname - end ---
  ## ```
  let capacityParam = "capacity".ident()
  result = quote do:
    proc new*(t: typedesc[ChannelHub], `capacityParam`: int = 500): ChannelHub =
      result = ChannelHub(channels: initTable[pointer, pointer]())
  
  for threadName in getRegisteredThreadnames():
    let variantType = newIdentNode(threadName.variantName)
    let addChannelLine = quote do:
      result.addChannel(`variantType`, `capacityParam`)
    result.body.add(addChannelLine)

proc genDestroyChannelHubProc*(): NimNode =
  ## Generates a proc `destroy` for destroying a ChannelHub.
  ## 
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
    let closeChannelLine = genAst(hubParam, variantType):
      hubParam.clearServerChannel(variantType)
      hubParam.getChannel(variantType).destroyChannel()
      let channelPtr = hubParam.getChannel(variantType).addr
      freeShared(channelPtr)
      notice "Destroyed Channel ", typ = $variantType, channelInt = cast[uint64](channelPtr)
      
    result.body.add(closeChannelLine)
  
proc genSendKillMessageProc*(name: ThreadName): NimNode =
  ## Generates a proc `sendKillMessage`.
  ## 
  ## These procs send a message that triggers the graceful shutdown of a thread.
  ## The thread to send the message to is inferred based on the object-variant for messages to that thread.
  ## The name of the object-variant is inferred from `name` via `variantName`_.
  let variantType = newIdentNode(name.variantName)
  let killKind = newIdentNode(name.killKindName)
  let senderProcName = newIdentNode(channelHub.SEND_PROC_NAME) # This string depends on the name 
  let serverSignal = name.signalName().ident()
  let threadName = newStrLitNode(name.string)
  
  result = quote do:
    proc sendKillMessage*(hub: ChannelHub, msg: typedesc[`variantType`]) =
      let killMsg = `variantType`(kind: `killKind`)
      discard hub.`senderProcName`(killMsg)
      
      let response = `serverSignal`.fireSync()
      while not `serverSignal`.fireSync().isOk():
        notice "Failed to wake up threadServer for kill message: " & `threadName`

proc genInitServerProc*(name: ThreadName): NimNode =
  ## Generates a proc `initServer(hub: ChannelHub, typ: typedesc[<name>Message]): Server[<name>Message]`.
  ## 
  ## These procs instantiate a threadServer object which can then be run, which starts the server.
  let variantType = newIdentNode(name.variantName)
  let signalVariable = newIdentNode(name.signalName)
  
  result = quote do:
    proc initServer*(hub: ChannelHub, typ: typedesc[`variantType`]): Server[`variantType`] =
      result = Server[`variantType`]()
      result.msgType = default(`variantType`)
      result.hub = hub
      result.signalReceiver = `signalVariable`
  
  for property in name.getProperties():
    property[0].assertKind(nnkIdent)
    let propertyName = $property[0]
    let propertyValue = property[1]
    
    let assignment = nnkAsgn.newTree(
      nnkDotExpr.newTree(
        newIdentNode("result"),
        newIdentNode(propertyName)
      ),
      propertyValue
    )
    result.body.add(assignment)

proc generateCode*(name: ThreadName): NimNode =
  ## Generates all types and procs needed for message-passing for `name`.
  ## 
  ## This proc should only be used by macros in this and other integration modules.

  result = newStmtList()
  
  let types = name.getTypes()
  
  let messageEnum = name.asEnum(types)
  result.add(messageEnum)
  
  let messageVariant = name.asVariant(types)
  result.add(messageVariant)
  
  result.add(name.asSignalVar())
  
  for typ in name.getTypes():
    result.add(genSenderProc(name, typ))

  let killServerProc = name.genSendKillMessageProc()
  result.add(killServerProc)
  
  let genInitServerProc = name.genInitServerProc()
  result.add(genInitServerProc)
  
  result.add(name.asThreadVar())

proc getSections*(body: NimNode): Table[Section, NimNode] =
  let sectionParents: seq[NimNode] = body.getNodesOfKind(nnkCall)
  for parentNode in sectionParents:
    let sectionName = parseEnum[Section]($parentNode[0])
    
    let sectionNode = parentNode[1]
    sectionNode.assertKind(nnkStmtList)
    
    result[sectionName] = sectionNode

macro threadServer*(name: static string, body: untyped) =
  ## Defines a threadServer called `name` and registers it and
  ## its contents in `body` with threadButler.
  ## 
  ## The `body` may declare any of these 3 sections:
  ## - properties
  ## - messageTypes
  ## - handlers
  ## 
  ## procs in the handler sections must have the shape:
  ## ```
  ## proc <procName>(msg: <YourMsgType>, hub: ChannelHub)
  ## ```
  ## 
  ## Generates all types and procs needed for message-passing for `name`:
  ## 1) An enum based representing all different types of messages that can be sent to the thread `name`.
  ## 2) An object variant that wraps any message to be sent through a channel to the thread `name`.
  ## 3) Generic `sendMessage` procs for sending messages to `name` by:
  ##      - receiving a message-type
  ##      - wrapping it in the object variant from 2)
  ##      - sending that to a channel to the thread `name`.
  ## 4) Specific `sendKillMessage` procs for sending a "kill" message to `name`
  ## 5) An (internal) `initServer` proc to create a Server
  ## 6) A global variable that contains the thread that `name` runs on
  ## 
  ## Note, this does not include all generated code. 
  ## See `prepareServers`_ for the remaining code that should be called
  ## after all threadServers have been declared.
  body.expectKind(nnkStmtList)
  let name = name.ThreadName
  body.validateSectionNames()
  name.registerThread()
  let sections = body.getSections()
  
  let hasTypes = sections.hasKey(MessageTypes)
  if hasTypes:
    let typeSection = sections[MessageTypes]
    name.validateTypeSection(typeSection)
    for typ in typeSection:
      name.addType(typ)
  
  let hasHandlers = sections.hasKey(Handlers)
  if hasHandlers:
    let handlerSection = sections[Handlers]
    name.validateHandlerSection(handlerSection)
    for handler in handlerSection:
      name.addRoute(handler)
  
  name.validateAllTypesHaveHandlers()
  
  let hasProperties = sections.hasKey(Properties)
  if hasProperties:
    let propertiesSection = sections[Properties]
    name.validatePropertiesSection(propertiesSection)
    for property in propertiesSection:
      name.addProperty(property)
  
  result = name.generateCode()
  
  when defined(butlerDebug):
    echo fmt"=== Actor: {name.string} ===", "\n", result.repr
    
macro prepareServers*() =
  ## Generates the remaining code that can only be provided once all 
  ## threadServers have been defined and are known by threadButler.
  ## 
  ## The generated procs are:
  ## 1) A routing proc for every registered thread. See `genMessageRouter`_ for specifics.
  ## 2) A `new(ChannelHub)` proc to instantiate a ChannelHub
  ## 3) A `destroy` proc to destroy a ChannelHub
  result = newStmtList()

  result.add(genNewChannelHubProc())
  result.add(genDestroyChannelHubProc())
  
  for name in getRegisteredThreadnames():
    let handlers = name.getRoutes()
    for handler in handlers:
      result.add(handler)
    
    let routingProc = name.genMessageRouter(handlers, name.getTypes())
    result.add(routingProc)
  
  when defined(butlerDebug):
    echo "=== Overall ===\n", result.repr
    