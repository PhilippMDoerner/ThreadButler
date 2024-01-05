import std/[macros, tables, macrocache, sequtils]
import ../codegen
import ../register
import ../validation
import ../types

when defined(butlerDebug):
  import std/[strformat, sequtils]

const owlThreads = CacheSeq"owl"

##[

Defines all code for owlkettle-specific code generation.
This is an extension of the `codegen` module.

]##

macro owlThreadServer*(name: static string, body: untyped) =
  ## An owlkettle specific version of `threadServer`_ .
  ## 
  ## Differs from `threadServer` by requiring procs in the 
  ## handler section to have a different shape: 
  ## ```
  ## proc <procName>(msg: <YourMsgType>, hub: ChannelHub, state: <Widget>State)
  ## ```
  body.expectKind(nnkStmtList)
  let name = name.ThreadName
  body.validateSectionNames()
  name.registerThread()
  owlThreads.add(newStrLitNode(name.string))
  
  let sections = body.getSections()
  
  let hasTypes = sections.hasKey(MessageTypes)
  if hasTypes:
    let typeSection = sections[MessageTypes]
    name.validateTypeSection(typeSection)
    for typ in typeSection:
      name.addType(typ)
  
  let hasHandlers = sections.hasKey(Handlers)
  if hasHandlers:
    let handlerSection = sections[Handlers]
    name.validateHandlerSection(handlerSection, expectedParamCount = 3)
    for handler in handlerSection:
      name.addRoute(handler)
  
  name.validateAllTypesHaveHandlers()
  
  let hasProperties = sections.hasKey(Properties)
  if hasProperties:
    let propertiesSection = sections[Properties]
    name.validatePropertiesSection(propertiesSection)
    for property in propertiesSection:
      name.addProperty(property)
  
  result = name.generateCode()
  
  when defined(butlerDebug):
    echo fmt"=== Actor: {name.string} ===", "\n", result.repr
    

proc genOwlRouter(name: ThreadName, widgetName: string): NimNode =
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

  result = newProc(name = postfix(ident("routeMessage"), "*"))

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

macro prepareOwlServers*(widgetNode: typed) =
  ## An owlkettle specific version of `prepareServers`_ .
  ## 
  ## Differs from `prepareServers` by generating a special routing proc instead of the "normal"
  ## one from `genMessageRouter`_  for threadServers defined with `owlThreadServer`_ .
  let widgetName = $widgetNode
  result = newStmtList()

  result.add(genNewChannelHubProc())
  result.add(genDestroyChannelHubProc())
  
  for name in getRegisteredThreadnames():
    let handlers = name.getRoutes()
    for handler in handlers:
      result.add(handler)
    
    let isClientThread: bool = owlThreads.toSeq().anyIt($it == name.string)
    let routingProc: NimNode = if isClientThread:
        name.genOwlRouter(widgetName)
      else:
        name.genMessageRouter(name.getRoutes(), name.getTypes())
    result.add(routingProc)
  
  when defined(butlerDebug):
    echo "=== OverallOwl ===\n", result.repr
