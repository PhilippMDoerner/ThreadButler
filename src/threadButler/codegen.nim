import std/[macros, strformat, strutils, unicode, sequtils]
import ./utils
import ./macroCacheUtils
import ./channelHub

## Defines all code for code generation in thread butler.
## All names of generated types are inferred from the name they are being registered with.
## All names of fields and enum kinds are inferred based on the data registered.

# TODO: 
# 5) Add support for running multiple servers - This also requires support for modifying the type-names based on the Server. So Servers should be able to have names which you can use during codegen. Either add names via pragma or as a field
# 6) Change syntax to be more proc-like - Creating a server creates a server object, you attach routes to it and then start it in the end. You can generate code during this process.

# Cleanup Todo:
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

proc fieldName*(node: NimNode): string =
  ## Infers the name of a field on a Message-object-variant-type from a type
  node.assertKind(@[nnkTypeDef])
  let typeName = node.typeName()
  return normalize(typeName) & "Msg"

proc extractProcDefs(node: NimNode): seq[NimNode] =
  ## Extracts nnkProcDef-NimNodes from a given node.
  ## Does not extract all nnkProcDef-NimNodes, only those that were added using supported Syntax.
  ## Supported syntax variations are:
  ## ```
  ## 1) myMacro(myProc)
  ## 2) myMacro():
  ##      proc myProc1() = <myProc1Implementation>
  ##      proc myProc2() = <myProc2Implementation>
  ## 3) proc myProc() {.myMacro.} = <myProcImplementation>
  ## ```
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
  ## Supports various syntax-constellations, see `extractProcDefs`.
  ## This does not change or remove any proc definitions this macro is applied to.
  ## Registered procs are used for code-generation with various macros, e.g. `generate`. 
  ## This does not generate code on its own.
  input.expectKind(
    @[nnkProcDef, nnkSym, nnkStmtList], 
    fmt"""
      Tried to register `{strutils.strip(input.repr)}` as serverRoute with unsupported syntax!
      The following are supported:
        - proc myProc(msg: SomeType, hub: ChannelHub[X, Y]){"\{.registerRouteFor\: \"<someName>\".\}"} = <Your Implementation>
        - registerRouteFor("<someName>", myProc)
        - registerRouteFor("<someName>"):
          proc myProc(msg: SomeType, hub: ChannelHub[X, Y]) = <Your Implementation>
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
  ## Supported syntax variations are:
  ## ```
  ## 1) myMacro(myType)
  ## 2) myMacro():
  ##      type myType1 = <myTypeDef1>
  ## 3) myMacro():
  ##      type 
  ##        myType1 = <myTypeDef1>
  ##        myType2 = <myTypeDef2>  
  ## ```
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
        error(fmt"'typ' macro does not support inner node of kind '{subNode.kind}'")
  else:
    error(fmt"'typ' macro does not support kind '{node.kind}'")
  

macro registerTypeFor*(name: string, input: typed) =
  ## Registers a type of a message for `name` with threadButler.
  ## This does not change or remove any type definition this macro is applied to.
  ## Supports various syntax-constellations, see `extractTypeDefs`.
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

proc asEnum*(name: ThreadName, types: seq[NimNode]): NimNode =
  ## Generates an enum type for `name`.
  ## The name of the enum-type is inferred from `name`, see the proc `enumName`.
  ## The enum is generated according to the pattern:
  ## ```
  ##  type <name>Kinds = enum
  ##    --- Repeat per type - start ---
  ##    <type>Kind
  ##    --- Repeat per type - end ---
  ## ```
  ## Returns an enum with a single enum-value "none" if types is empty.
  let hasTypes = types.len > 0
  
  let enumFields: seq[NimNode] = if not hasTypes:
      @[ident("none")] # Fallback when no message type is provided
    else:
      types.mapIt(ident(it.kindName))
  
  return newEnum(
    name = ident(name.enumName), 
    fields = enumFields, 
    public = true,
    pure = true
  )

proc asVariant*(name: ThreadName, types: seq[NimNode] ): NimNode =
  ## Generates a ref object variant type for `name`.
  ## The name of the object-variant-type is inferred from `name`, see the proc `variantName`_.
  ## Uses the enum-type generated by `asEnum`_ for the discriminator.
  ## The variant is generated according to the pattern:
  ## ```
  ##  type <name>Message = ref object
  ##    case kind: <enumName>
  ##    --- Repeat per type - start ---
  ##    of <enumKind>: 
  ##      <type>Msg: <type>
  ##    --- Repeat per type - end ---
  ## ```
  ## Returns a ref object without any fields if types is empty.
  let hasTypes = types.len() > 0
  if not hasTypes:
    let typeName = newIdentNode(name.variantName)
    return quote do:
      type `typeName` = ref object 

  let caseNode = nnkRecCase.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("kind"),
      newIdentNode(name.enumName),
      newEmptyNode()
    )
  )
  
  for typ in name.getTypes():
    typ.assertKind(nnkTypeDef)
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(typ.kindName),
      nnkRecList.newTree(
        newIdentDefs(
          newIdentNode(typ.fieldName),
          ident(typ.typeName)
        ) 
      )
    )
    
    caseNode.add(branchNode)
  
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
  ## Uses the object-variant generated by `asVariant`_.
  ## The proc is generated based on the registered routes according to this pattern:
  ## ```
  ##  proc routeMessage\*[SMsg, CMsg](msg: <ObjectVariant>, hub: ChannelHub[SMsg, CMsg]) =
  ##    case msg.kind:
  ##    --- Repeat per route - start ---
  ##    of <enumKind>:
  ##      <handlerProc>(msg.<variantField>, hub)
  ##    --- Repeat per route - end ---
  ## ```
  ## Returns an empty proc if types is empty
  result = newProc(name = postfix(ident("routeMessage"), "*"))
  let genericParams = nnkGenericParams.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("SMsg"),
      newIdentNode("CMsg"),
      newEmptyNode(),
      newEmptyNode()
    )
  )
  result[2] = genericParams # 2 = Proc Node for generic params
  
  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(name.variantName))
  result.params.add(msgParam)
  
  let hubParam = newIdentDefs(
    ident("hub"), 
    nnkBracketExpr.newTree(
      ident("ChannelHub"),
      ident("SMsg"),
      ident("CMsg")
    )
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
    
  result.body.add(caseStmt)

proc genSenderProc*(name: ThreadName, typ: NimNode): NimNode =
  ## Generates a generic proc `sendMessage`.
  ## These procs can be used by any thread to send messages to thread `name`.
  ## They "wrap" the message of type `typ` in the object-variant 
  ## generated by `asVariant` before sending that message through the corresponding `Channel`.
  typ.assertKind(nnkTypeDef)
  
  let procName = newIdentNode("sendMessage")
  let msgType = newIdentNode(typ.typeName)
  let variantType = newIdentNode(name.variantName)
  let msgKind = newIdentNode(typ.kindName)
  let variantField = newIdentNode(typ.fieldName)
  let senderProcName = newIdentNode(channelHub.SEND_PROC_NAME) # This string depends on the name 
  
  quote do:
    proc `procName`*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: `msgType`): bool =
      let msgWrapper: `variantType` = `variantType`(kind: `msgKind`, `variantField`: msg)
      return hub.`senderProcName`(msgWrapper)


proc generateCode(name: ThreadName): NimNode =
  result = newStmtList()
  
  let types = name.getTypes()
  
  let messageEnum = name.asEnum(types)
  result.add(messageEnum)
  
  let messageVariant = name.asVariant(types)
  result.add(messageVariant)
  
  let routerProc = name.genMessageRouter(name.getRoutes(), name.getTypes())
  result.add(routerProc)
  
  for typ in name.getTypes():
    result.add(genSenderProc(name, typ))

macro generate*(name: string): untyped =
  ## Generates all types and procs needed for message-passing for `name`:
  ## 1) An enum based representing all different types of messages that can be sent to the thread `name`.
  ## 2) An object variant that wraps any message to be sent through a channel to the thread `name`.
  ## 3) A generic routing proc for the thread `name` to:
  ##      - receive the message object variant from 2)
  ##      - unwrap it
  ##      - call a handler proc with the unwrapped message.
  ## 4) Generic procs for sending messages to `name` by:
  ##      - receiving a message-type
  ##      - wrapping it in the object variant from 2)
  ##      - sending that to a channel to the thread `name`.
  let name: ThreadName = name.toThreadName()

  result = name.generateCode()

  when defined(butlerDebug):
    echo result.repr