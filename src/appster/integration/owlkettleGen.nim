import ../typegen
import std/[macros, strformat]
import ../macroCacheUtils

proc genOwlRouter(name: string): NimNode =
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
    let handlerCall = nnkCall.newTree(
      handlerProc.name,
      newDotExpr(ident(msgParamName), ident(handlerProc.fieldName)),
      ident(hubParamName),
      ident(stateParamName)
    )
    
    # Generates `of <kind>: <handlerProc>(...)`
    let branchNode = nnkOfBranch.newTree(
      ident(handlerProc.kindName),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)

proc generateOwlCode(name: ThreadName): NimNode = 
  result = newStmtList()
  
  result.addTypeCode(name)
  result.add(name.genOwlRouter())
  
  for handlerProc in name.getRoutes():
    result.add(genSenderProc(name, handlerProc))

macro owlGenerate*(name: ThreadName): typed =
  let name = $name
  
  result = name.generateOwlCode()

  when defined(appsterDebug):
    echo result.repr

macro owlGenerateAll*(clientName: ThreadName) =
  let clientName = $clientName
  result = newStmtList()
  for threadName in getRegisteredThreadnames():
    let isForClient = clientName == threadName
    let generatedNodes: NimNode = if isForClient:
        generateOwlCode(threadName)
      else:
        generateCode(threadName)
    
    for node in generatedNodes:
      result.add(node)