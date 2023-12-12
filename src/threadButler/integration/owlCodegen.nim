import ../codegen
import std/[macros]
import ../register

##[

Defines all code for owlkettle-specific code generation.
This is an extension of the `codegen` module.

.. note:: Only the macros provided here are for documentation purposes.

]##

proc genOwlRouter*(name: ThreadName, widgetName: string): NimNode =
  ## Generates a proc `routeMessage` for unpacking the object variant type for `name` and calling a handler proc with the unpacked value.
  ## The variantTypeName is inferred from `name`, see the proc `variantName`_.
  ## The name of the killKind is inferred from `name`, see the proc `killKindName`_.
  ## The name of msgField is inferred from `type`, see the proc `fieldName`_.
  ## The proc is generated based on the registered routes according to this pattern:
  ## ```
  ##  proc routeMessage\*(msg: <variantTypeName>, hub: ChannelHub, state: <widgetName>State) =
  ##    case msg.kind:
  ##    --- Repeat per route - start ---
  ##    of <enumKind>:
  ##      <handlerProc>(msg.<msgField>, hub, state)
  ##    --- Repeat per route - end ---
  ##    of <killKind>: shutDownServer()
  ## ```
  ## Returns an empty proc if types is empty

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
  ## Generates a routing proc for every registered thread.
  ## The thread `clientThreadName` will generate a special routing proc 
  ## for the owlkettle client. 
  ## See also:
  ## * `genMessageRouter`_ - for specifics for the usual routing proc.
  ## * `genOwlRouter`_ - for specifics for the owlkettle specific routing proc.
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