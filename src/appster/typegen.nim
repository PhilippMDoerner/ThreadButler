import std/[macros, macrocache]

const clientRoutes = CacheTable"clientRouteTable"
const serverRoutes = CacheTable"serverRouteTable"

type Message* = concept m
  m.kind is enum

macro registerClientRoute*(name: static[string], typNode: typed) =
  clientRoutes[name] = typNode

macro registerServerRoute*(name: static[string], typNode: typed) =
  serverRoutes[name] = typNode

proc asEnum(tbl: CacheTable, enumName: string): NimNode =
  var fields: seq[NimNode] = @[]
  for field, value in tbl:
    fields.add(ident(field))
  
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
      newIdentNode(name),
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
  ## Generates proc routeMessage(msg: `msgVariantTypeName`, hub: ChannelHub)
  ## Which is a gigantic switch-case statement over all kinds of the variant

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
    # Generates "handleMessage(`msgParamName`.`fieldName`, hub)"
    let handlerCall = nnkCall.newTree(
      ident("handleMessage"),
      newDotExpr(ident(msgParamName), ident(fieldName)),
      ident("hub")
    )
    
    # Generates "of `routeName`: `handlerCall`"
    let branchNode = nnkOfBranch.newTree(
      ident(routeName),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)
  echo result.repr
  

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