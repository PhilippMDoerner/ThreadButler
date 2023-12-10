import std/[macros, macrocache, strformat, strutils, unicode, sequtils]
import ./utils
import ./macroCacheUtils
import ./communication

const routes = CacheTable"routeTable"
const msgTypes = CacheTable"msgTypes"

## TODO: 
## 4) Add support for distinct message types
## 5) Add support for running multiple servers - This also requires support for modifying the type-names based on the Server. So Servers should be able to have names which you can use during codegen. Either add names via pragma or as a field
## 6) Change syntax to be more proc-like - Creating a server creates a server object, you attach routes to it and then start it in the end. You can generate code during this process.

type Message* = concept m
  m.kind is enum

type RouteName* = string
type ThreadName* = string

proc variantName*(x: ThreadName): string = x.capitalize() & "Message"
proc enumName*(x: ThreadName): string = x.capitalize() & "Kinds"
proc firstParamName*(node: NimNode): string =
  node.assertKind(@[nnkProcDef])
  let firstParam = node.params[1]
  firstParam.assertKind(nnkIdentDefs)
  return $firstParam[0]

proc firstParamType*(node: NimNode): string =
  node.assertKind(@[nnkProcDef])
  let firstParam = node.params[1]
  firstParam.assertKind(nnkIdentDefs)
  return $firstParam[1]

proc kindName(x: RouteName): string = x.capitalize() & "Kind"
proc kindName*(node: NimNode): string =
  node.assertKind(@[nnkProcDef])
  return node.firstParamType & "Kind"

proc fieldName(x: RouteName): string = x.string & "Msg"
proc fieldName*(node: NimNode): string =
  node.assertKind(@[nnkProcDef])
  return node.firstParamType.normalize() & "Msg"

proc getProcDef(node: NimNode): NimNode =
  ## Utility proc. Tries to extract a procDef from `node`.
  node.assertKind(@[nnkProcDef, nnkSym])
  
  return case node.kind:
    of nnkProcDef: node
    of nnkSym:
      node.getImpl()
    else:
      raise newException(ValueError, fmt"Developer Error: The supported NimNodeKind {node.kind} was not dealt with!")

proc isDefiningProc(node: NimNode): bool = node.kind in [nnkProcDef]
  
macro route*(name: string, input: typed): untyped =
  ## Registers a proc for handling messages as "server route" with appster.
  ## This is used for code-generation with `generate()`
  input.expectKind(
    @[nnkProcDef, nnkSym], 
    fmt"""
      Tried to register `{strutils.strip(input.repr)}` as serverRoute with unsupported syntax!
      The following are supported:
        - proc myProc(msg: SomeType, hub: ChannelHub[X, Y]){"\{.serverRoute.\}"}
        - serverRoute(myProc)
    """.dedent(6)
  )
  
  let procDef = input.getProcDef()
  input.expectKind(nnkProcDef)
  addRoute($name, procDef)
  
  if input.isDefiningProc():
    return input ## Necessary so that the defined proc does not "disappear"


proc asEnum(name: ThreadName): NimNode =
  ## Generates an enum type `enumName` with all keys in `routes` turned into enum values.
  let routes = name.getRoutes()
  let hasRoutes = routes.len > 0
  
  let enumFields: seq[NimNode] = if not hasRoutes:
      @[ident("none")] # Fallback when no message type is provided
    else:
      name.getRoutes().mapIt(ident(it.kindName))
  
  newEnum(
    name = ident(name.enumName), 
    fields = enumFields, 
    public = true,
    pure = true
  )

proc asVariant(name: string): NimNode =
  ## Generates an object variant type `typeName` using the enum called `enumName`.
  ## Each variation of the variant has 1 field. 
  ## The type of that field is the message type stored in the NimNode in `routes`.
  ## Returns a simple object type with no fields if no routes are registered
  if not name.hasRoutes():
    let typeName = newIdentNode(name.variantName)
    return quote do:
      type `typeName` = object 

  let caseNode = nnkRecCase.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("kind"),
      newIdentNode(name.enumName),
      newEmptyNode()
    )
  )
  
  for handlerProc in name.getRoutes():
    handlerProc.assertKind(nnkProcDef)
    
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(handlerProc.kindName),
      newIdentDefs(
        newIdentNode(handlerProc.fieldName),
        ident(handlerProc.firstParamType)
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
  
proc genMessageRouter(name: string): NimNode =
  ## Generates "proc routeMessage(msg: `msgVariantTypeName`, hub: ChannelHub)".
  ## `msgVariantTypeName` must be the name of an object variant type.
  ## The procs body is a gigantic switch-case statement over all kinds of `msgVariantTypeName`

  let returnTyp = newEmptyNode()
  result = newProc(name = postfix(ident("routeMessage"), "*"))
  
  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(name.variantName))
  result.params.add(msgParam)
  
  let hubParam = newIdentDefs(ident("hub"), ident("ChannelHub"))
  result.params.add(hubParam)
  
  let caseStmt = nnkCaseStmt.newTree(
    newDotExpr(ident(msgParamName), ident("kind"))
  )
  
  for handlerProc in name.getRoutes():
    # Generates proc call `<routeName>(<msgParamName>.<fieldName>, hub)`
    let handlerCall = nnkCall.newTree(
      handlerProc.name,
      newDotExpr(ident(msgParamName), ident(handlerProc.fieldName)),
      ident("hub")
    )
    
    # Generates `of <routeName>: <handlerCall>`
    let branchNode = nnkOfBranch.newTree(
      ident(handlerProc.kindName),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)

proc genSenderProc*(name: ThreadName, handlerProc: NimNode): NimNode =
  ## Generates a procedure to send messages to the server via ChannelHub and hiding the object variant.
  let procName = newIdentNode("sendMessage")
  let msgType = newIdentNode(handlerProc.firstParamType)
  let variantType = newIdentNode(name.variantName)
  let msgKind = newIdentNode(handlerProc.kindName)
  let variantField = newIdentNode(handlerProc.fieldName)
  let senderProcName = newIdentNode(communication.SEND_PROC_NAME) # This string depends on the name 
  
  quote do:
    proc `procName`*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: `msgType`): bool =
      let msgWrapper: `variantType` = `variantType`(kind: `msgKind`, `variantField`: msg)
      return hub.`senderProcName`(msgWrapper)

proc addTypeCode*(
  node: NimNode, 
  name: ThreadName, 
) =
  ## Adds the various pieces of code that need to be generated to the output
  let hasRoutes = routes.len() > 0    
  let messageEnum = name.asEnum()
  node.add(messageEnum)
  
  let messageVariant = name.asVariant()
  node.add(messageVariant)
  
macro generate*(name: ThreadName): untyped =
  let name = $name
  result = newStmtList()
  
  result.addTypeCode(name)
  result.add(name.genMessageRouter())
  
  for handlerProc in name.getRoutes():
    result.add(genSenderProc(name, handlerProc))

  when defined(appsterDebug):
    echo result.repr