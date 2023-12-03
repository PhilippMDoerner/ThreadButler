import std/[macros, macrocache, strformat, strutils]
import ./utils

const clientRoutes = CacheTable"clientRouteTable"
const serverRoutes = CacheTable"serverRouteTable"

## TODO: 
## 4) Add support for distinct message types
## 5) Add support for running multiple servers - This also requires support for modifying the type-names based on the Server. So Servers should be able to have names which you can use during codegen. Either add names via pragma or as a field
## 6) Change syntax to be more proc-like - Creating a server creates a server object, you attach routes to it and then start it in the end. You can generate code during this process.

type Message* = concept m
  m.kind is enum

type RouteName = string

proc kindName(x: RouteName): string = x.string & "Kind"
proc fieldName(x: RouteName): string = x.string & "Msg"

proc addRoute*(routes: CacheTable, procDef: NimNode) =
  ## Stores a proc definition as "route" in `routes`.
  ## The proc's name is used as name of the route.
  procDef.assertKind(nnkProcDef, "You need a proc definition to add a route in order to extract the first parameter")
    
  let procName: string = $procDef.name
  if routes.hasKey(procName):
    let otherProcLine: string = routes[procName].lineInfo
    error(
      fmt"""'{procName}' could not be registered. 
        A proc with that name was already registered!
        Previous proc declaration here: {otherProcLine}
      """.dedent(8), 
      procDef
    )
  
  let firstParam = procDef.params[1]
  let firstParamType = firstParam[1]
  routes[procName] = firstParamType

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
  

macro clientRoute*(input: typed): untyped =
  ## Registers a proc for handling messages as "client route" with appster.
  ## This is used for code-generation with `generate()`
  input.expectKind(
    @[nnkProcDef, nnkSym], 
    fmt"""
      Tried to register `{input.repr.strip()}` as clientRoute with unsupported syntax!
      The following are supported:
        - proc myProc(msg: SomeType, hub: ChannelHub[X, Y]){"\{.clientRoute.\}"}
        - clientRoute(myProc)
    """.dedent(6)
  )
  
  let procDef = input.getProcDef()
  clientRoutes.addRoute(procDef)
  
  if input.isDefiningProc():
    return input ## Necessary so that the defined proc does not "disappear"

macro serverRoute*(input: typed): untyped =
  ## Registers a proc for handling messages as "server route" with appster.
  ## This is used for code-generation with `generate()`
  input.expectKind(
    @[nnkProcDef, nnkSym], 
    fmt"""
      Tried to register `{input.repr.strip()}` as serverRoute with unsupported syntax!
      The following are supported:
        - proc myProc(msg: SomeType, hub: ChannelHub[X, Y]){"\{.serverRoute.\}"}
        - serverRoute(myProc)
    """.dedent(6)
  )
  
  let procDef = input.getProcDef()
  serverRoutes.addRoute(procDef)
  
  if input.isDefiningProc():
    return input ## Necessary so that the defined proc does not "disappear"


proc asEnum(routes: CacheTable, enumName: string): NimNode =
  ## Generates an enum type `enumName` with all keys in `routes` turned into enum values.
  var enumFields: seq[NimNode] = @[]
  for routeName, _ in routes:
    enumFields.add(ident(routeName.kindName))
  
  newEnum(
    name = ident(enumName), 
    fields = enumFields, 
    public = true,
    pure = true
  )

proc asVariant(routes: CacheTable, enumName: string, typeName: string): NimNode =
  ## Generates an object variant type `typeName` using the enum called `enumName`.
  ## Each variation of the variant has 1 field. 
  ## The type of that field is the message type stored in the NimNode in `routes`.

  let caseNode = nnkRecCase.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("kind"),
      newIdentNode(enumName),
      newEmptyNode()
    )
  )
  
  for routeName, msgTypeName in routes:
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(routeName.kindName),
      newIdentDefs(
        newIdentNode(routeName.fieldName),
        msgTypeName
      )
    )
    
    caseNode.add(branchNode)
  
  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      newIdentNode(typeName),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree( caseNode )
      )
    )
  )
  
proc genMessageRouter(routes: CacheTable, msgVariantTypeName: string): NimNode =
  ## Generates "proc routeMessage(msg: `msgVariantTypeName`, hub: ChannelHub)".
  ## `msgVariantTypeName` must be the name of an object variant type.
  ## The procs body is a gigantic switch-case statement over all kinds of `msgVariantTypeName`

  let returnTyp = newEmptyNode()
  result = newProc(name = ident("routeMessage"))
  
  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(msgVariantTypeName))
  result.params.add(msgParam)
  
  let hubParam = newIdentDefs(ident("hub"), ident("ChannelHub"))
  result.params.add(hubParam)
  
  let caseStmt = nnkCaseStmt.newTree(
    newDotExpr(ident(msgParamName), ident("kind"))
  )
  
  for routeName, _ in routes:
    let fieldName = routeName & "Msg"
    # Generates proc call `<routeName>(<msgParamName>.<fieldName>, hub)`
    let handlerCall = nnkCall.newTree(
      ident(routeName),
      newDotExpr(ident(msgParamName), ident(routeName.fieldName)),
      ident("hub")
    )
    
    # Generates `of <routeName>: <handlerCall>`
    let branchNode = nnkOfBranch.newTree(
      newDotExpr(ident(msgVariantTypeName & "Kind"), ident(routeName & "Kind")),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)

proc genSenderProc(procName: string, msgVariantTypeName: string, routeName: string, msgTypeName: string, hubSenderProc: string): NimNode =
  ## Generates a procedure to send messages to the server via ChannelHub and hiding the object variant.
  let procNode = newIdentNode(procName)
  let typeNode = newIdentNode(msgTypeName)
  let variantTypeNode = newIdentNode(msgVariantTypeName)
  let kindNode = newIdentNode(routeName.kindName)
  let fieldNode = newIdentNode(routeName.fieldName)
  let hubSenderProcNode = newIdentNode(hubSenderProc)
  
  quote do:
    proc `procNode`[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: `typeNode`): bool =
      let msgWrapper: `variantTypeNode` = `variantTypeNode`(kind: `kindNode`, `fieldNode`: msg)
      return hub.`hubSenderProcNode`(msgWrapper)
      
proc addTypeCode(
  node: NimNode, 
  routes: CacheTable, 
  enumName, typeName: string
) =
  ## Adds the various pieces of code that need to be generated to the output
  ## TODO: Clean this up. The idea here is that you need to have something functional even if there are no messages going S => C or C => S
  let hasRoutes = routes.len() > 0
  if not hasRoutes:
    # Fallback, generate empty object type
    let typeNode = ident(typeName)
    let emptyObjectType = quote do:
      type `typeNode` = object
    
    node.add(emptyObjectType)
    return
    
  let messageEnum = routes.asEnum(enumName)
  node.add(messageEnum)
  
  let messageVariant = routes.asVariant(enumName, typeName)
  node.add(messageVariant)
  
  let routerProc = routes.genMessageRouter(typeName)
  node.add(routerProc)

proc addProcCode(
  node: NimNode,
  targetRoutes: CacheTable,
  variantTypeName, procName, hubSendProc: string, 
) =
  for routeName, msgType in targetRoutes:
    let sendProcDef = genSenderProc(
      procName, 
      variantTypeName, 
      routeName, 
      $msgType, 
      hubSendProc
    )
    node.add(sendProcDef)

macro generate*(send2ServerName: string = "sendToServer", send2ClientName: string = "sendToClient"): untyped =
  result = newStmtList()
  let fromClientMsg = "ClientMessage"
  let fromServerMsg = "ServerMessage"
  
  ## Add enum "ServerMessageKind" and object variant "ServerMessage"
  ## for servers to send messages to clients 
  ## This is client <= server. ServerMessages come from the Server
  result.addTypeCode(
    clientRoutes, 
    fromServerMsg.kindName, 
    fromServerMsg
  )
  
  ## Add enum "ClientMessageKind" and object variant "ClientMessage" types 
  ## for servers to send messages to client.
  ## This is client => server. ClientMessages come from the Client
  result.addTypeCode(
    serverRoutes, 
    fromClientMsg.kindName, 
    fromClientMsg
  )
  
  ## Add sender procs for clients to send messages to the server.
  ## This is for client <= server. 
  result.addProcCode(
    clientRoutes,
    fromServerMsg,
    $send2ClientName,
    "sendMsgToClient"
  )
  
  ## Add sender procs for server to send messages to the client.
  ## This is for client => server. 
  result.addProcCode(
    serverRoutes,
    fromClientMsg,
    $send2ServerName,
    "sendMsgToServer"
  )

  when defined(appsterDebug):
    echo result.repr