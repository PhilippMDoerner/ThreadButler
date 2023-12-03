import std/[macros, macrocache, strformat, strutils]

const clientRoutes = CacheTable"clientRouteTable"
const serverRoutes = CacheTable"serverRouteTable"

type Message* = concept m
  m.kind is enum

proc addRoute*(routes: CacheTable, procDef: NimNode) =
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

macro clientRoute*(procDef: typed): untyped =
  ## Registers the client route with appster for code-generation with `generate()`
  clientRoutes.addRoute(procDef)
  
  return procDef

macro serverRoute*(procDef: typed): untyped =
  ## Registers the server route with appster for code-generation with `generate()`
  serverRoutes.addRoute(procDef)
  
  return procDef

proc asEnum(tbl: CacheTable, enumName: string): NimNode =
  var fields: seq[NimNode] = @[]
  for field, value in tbl:
    fields.add(ident(field & "Kind"))
  
  newEnum(
    name = ident(enumName), 
    fields = fields, 
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
  
  for name, value in routes:
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(name & "Kind"),
      newIdentDefs(
        newIdentNode(name & "Msg"),
        value
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
    # Generates "`routeName`(`msgParamName`.`fieldName`, hub)"
    let procName: string = routeName
    let handlerCall = nnkCall.newTree(
      ident(procName),
      newDotExpr(ident(msgParamName), ident(fieldName)),
      ident("hub")
    )
    
    # Generates "of `routeName`: `handlerCall`"
    let branchNode = nnkOfBranch.newTree(
      newDotExpr(ident(msgVariantTypeName & "Kind"), ident(routeName & "Kind")),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)
  

proc addTypeNodes(node: NimNode, routes: CacheTable, enumName: string, typeName: string) =
  let messageEnum = routes.asEnum(enumName)
  node.add(messageEnum)
  
  let messageVariant = routes.asVariant(enumName, typeName)
  node.add(messageVariant)
  
  let routerProc = routes.genMessageRouter(typeName)
  node.add(routerProc)

macro generate*(): untyped =
  result = newStmtList()
  result.addTypeNodes(serverRoutes, "ServerMessageKind", "ServerMessage")
  result.addTypeNodes(clientRoutes, "ClientMessageKind", "ClientMessage")
  
  when defined(appsterDebug):
    echo result.repr

proc handleServerMessage*(msg: Message) =
  echo "Server Message: ", msg.repr
  
proc handleClientMessage*(msg: Message) =
  echo "Client Message: ", msg.repr