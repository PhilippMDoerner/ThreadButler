import ../codegen
import std/[macros]
import ../macroCacheUtils

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
    
  result.body.add(caseStmt)

proc generateOwlCode(name: ThreadName): NimNode =
  result = newStmtList()
  
  let types = name.getTypes()
  
  let messageEnum = name.asEnum(types)
  result.add(messageEnum)
  
  let messageVariant = name.asVariant(types)
  result.add(messageVariant)

  for typ in types:
    result.add(genSenderProc(name, typ))

macro owlSetup*() =
  result = newStmtList()
  for threadName in getRegisteredThreadnames():
    for node in threadName.generateOwlCode():
      result.add(node)
      
  when defined(butlerDebug):
    echo result.repr

macro routingSetup*(clientThreadName: string, widgetNode: typed) =
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