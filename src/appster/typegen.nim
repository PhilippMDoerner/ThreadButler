import std/[macros, macrocache, strformat, strutils]
import ./utils

const clientRoutes = CacheTable"clientRouteTable"
const serverRoutes = CacheTable"serverRouteTable"

type Message* = concept m
  m.kind is enum

type RouteName = string

proc kindName(x: RouteName): string = x.string & "Kind"
proc fieldName(x: RouteName): string = x.string & "Msg"

proc addRoute*(routes: CacheTable, procDef: NimNode) =
  procDef.assertKind(nnkProcDef, "\nYou need a proc definition to add a route in order to extract the first parameter")
    
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
  ## Utility proc. Checks if node is of a supported kind and tries to fetch a procDef from that if it is supported.
  node.assertKind(@[nnkProcDef, nnkSym])
  
  return case node.kind:
    of nnkProcDef: node
    of nnkSym:
      node.getImpl()
    else:
      raise newException(ValueError, fmt"Developer Error: The supported NimNodeKind {node.kind} was not dealt with!")

proc isDefiningProc(node: NimNode): bool = node.kind in [nnkProcDef]
  

macro clientRoute*(input: typed): untyped =
  ## Registers the client route with appster for code-generation with `generate()`
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
  ## Registers the server route with appster for code-generation with `generate()`
  
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


proc asEnum(tbl: CacheTable, enumName: string): NimNode =
  ## Generates an enum `enumName` with all keys in `tbl` turned into enum values.
  var enumFields: seq[NimNode] = @[]
  for routeName, _ in tbl:
    enumFields.add(ident(routeName.kindName))
  
  newEnum(
    name = ident(enumName), 
    fields = enumFields, 
    public = true,
    pure = true
  )

proc asVariant(routes: CacheTable, enumName: string, typeName: string): NimNode =
  let caseNode = nnkRecCase.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("kind"),
      newIdentNode(enumName),
      newEmptyNode()
    )
  )
  
  for routeName, msgType in routes:
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(routeName.kindName),
      newIdentDefs(
        newIdentNode(routeName.fieldName),
        msgType
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
  
  for routeName, msgType in routes:
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

proc addGeneratedNodes(node: NimNode, routes: CacheTable, enumName: string, typeName: string) =
  let messageEnum = routes.asEnum(enumName)
  node.add(messageEnum)
  
  let messageVariant = routes.asVariant(enumName, typeName)
  node.add(messageVariant)
  
  let routerProc = routes.genMessageRouter(typeName)
  node.add(routerProc)

macro generate*(): untyped =
  result = newStmtList()
  result.addGeneratedNodes(serverRoutes, "ServerMessageKind", "ServerMessage")
  result.addGeneratedNodes(clientRoutes, "ClientMessageKind", "ClientMessage")
  
  when defined(appsterDebug):
    echo result.repr