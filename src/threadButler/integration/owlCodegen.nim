import ../codegen
import std/[macros]
import ../register

proc genOwlRouter(name: ThreadName, widgetName: string): NimNode =
  ## Generates "proc routeMessage(msg: `msgVariantTypeName`, hub: ChannelHub)".
  ## `msgVariantTypeName` must be the name of an object variant type.
  ## The procs body is a gigantic switch-case statement over all kinds of `msgVariantTypeName`

  result = newProc(name = ident("routeMessage"))

  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(name.variantName))
  result.params.add(msgParam)
  
  let hubParamName = "hub"
  let hubParam = newIdentDefs(
    ident(hubParamName), 
    ident("ChannelHub")
  )
  result.params.add(hubParam)
  
  let stateParamName = "state"
  let widgetStateParam = newIdentDefs(ident(stateParamName), ident(widgetName & "State"))
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
    
  # Generates `of <killKind>: shutdownServer()`: 
  let killBranchNode = nnkOfBranch.newTree(
    ident(name.killKindName),
    nnkCall.newTree(ident("shutdownServer"))
  )
  caseStmt.add(killBranchNode)
  
  result.body.add(caseStmt)

macro generateOwlRouter*(clientThreadName: string, widgetNode: typed) =
  let clientThreadName = clientThreadName.toThreadName()
  let widgetName = $widgetNode
  result = newStmtList()
  
  for threadName in getRegisteredThreadnames():
    let isClientThread: bool = threadName == clientThreadName
    let routingProc: NimNode = if isClientThread:
        threadName.genOwlRouter(widgetName)
      else:
        threadName.genMessageRouter(threadName.getRoutes(), threadName.getTypes())
    result.add(routingProc)

  when defined(butlerDebug):
    echo result.repr