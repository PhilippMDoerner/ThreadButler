import ../typegen
import std/[macros]
import ../macroCacheUtils

proc genOwlRouter(name: ThreadName): NimNode =
  ## Generates "proc routeMessage(msg: `msgVariantTypeName`, hub: ChannelHub)".
  ## `msgVariantTypeName` must be the name of an object variant type.
  ## The procs body is a gigantic switch-case statement over all kinds of `msgVariantTypeName`

  let returnTyp = newEmptyNode()
  result = newProc(name = ident("routeMessage"))
  
  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(name.variantName))
  result.params.add(msgParam)
  
  let hubParamName = "hub"
  let hubParam = newIdentDefs(ident(hubParamName), ident("ChannelHub"))
  result.params.add(hubParam)
  
  let stateParamName = "state"
  let widgetStateParam = newIdentDefs(ident(stateParamName), ident("WidgetState"))
  result.params.add(widgetStateParam)
  
  let caseStmt = nnkCaseStmt.newTree(
    newDotExpr(ident(msgParamName), ident("kind"))
  )
  
  for handlerProc in name.getRoutes():
    # Generates proc call `<handlerProc>(<msgParamName>.<fieldName>, hub, state)`
    let firstParamType = handlerProc.firstParamType
    let handlerCall = nnkCall.newTree(
      handlerProc.name,
      newDotExpr(ident(msgParamName), ident(firstParamType.fieldName)),
      ident(hubParamName),
      ident(stateParamName)
    )
    
    # Generates `of <kind>: <handlerProc>(...)`
    let branchNode = nnkOfBranch.newTree(
      ident(firstParamType.kindName),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)

proc setup(name: ThreadName): NimNode =
  result = newStmtList()
  
  result.addTypeCode(name)
  for typ in name.getTypes():
    result.add(genSenderProc(name, typ))

macro owlSetup*(): typed =
  result = newStmtList()
  for threadName in getRegisteredThreadnames():
    for node in threadName.setup():
      result.add(node)
      
  when defined(appsterDebug):
    echo result.repr
    
macro routingSetup*(clientThreadName: ThreadName): typed =
  let clientThreadName = $clientThreadName
  result = newStmtList()
  
  for threadName in getRegisteredThreadnames():
    let isClientThread: bool = threadName == clientThreadName
    let routingProc: NimNode = if isClientThread:
        threadName.genOwlRouter()
      else:
        threadName.genMessageRouter()
    result.add(routingProc)

  when defined(appsterDebug):
    echo result.repr