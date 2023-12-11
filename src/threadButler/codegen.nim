import std/[macros, strformat, strutils, unicode, sequtils]
import ./utils
import ./macroCacheUtils
import ./channelHub

## TODO: 
## 5) Add support for running multiple servers - This also requires support for modifying the type-names based on the Server. So Servers should be able to have names which you can use during codegen. Either add names via pragma or as a field
## 6) Change syntax to be more proc-like - Creating a server creates a server object, you attach routes to it and then start it in the end. You can generate code during this process.

## Cleanup Todo:
## 1) Doc Comments on everything
## 2) Package tests maybe?
## 3) README.md

proc variantName*(x: ThreadName): string = x.string.capitalize() & "Message"
proc enumName*(x: ThreadName): string = x.string.capitalize() & "Kinds"
proc firstParamName*(node: NimNode): string =
  node.assertKind(@[nnkProcDef])
  let firstParam = node.params[1]
  firstParam.assertKind(nnkIdentDefs)
  return $firstParam[0]

proc kindName(x: string): string = capitalize(x) & "Kind"
proc kindName*(node: NimNode): string =
  node.assertKind(@[nnkTypeDef])
  return node.typeName.kindName()

proc fieldName(x: string): string = normalize(x) & "Msg"
proc fieldName*(node: NimNode): string =
  node.assertKind(@[nnkTypeDef])
  return fieldName(node.typeName())

proc getProcDef(node: NimNode): NimNode =
  ## Utility proc. Tries to extract a procDef from `node`.
  node.assertKind(@[nnkProcDef, nnkSym])
  
  return case node.kind:
    of nnkProcDef: node
    of nnkSym:
      node.getImpl()
    else:
      raise newException(ValueError, fmt"Developer Error: The supported NimNodeKind {node.kind} was not dealt with!")

proc toThreadName(node: NimNode): ThreadName =
  node.assertKind(@[nnkStrLit, nnkSym])
  
  case node.kind:
    of nnkStrLit: 
      let name = $node
      return ThreadName(name)
    
    of nnkSym: 
      let constExpression: NimNode = node.getImpl()
      let valueNode: NimNode = constExpression[2]
      let value: string = $valueNode
      return ThreadName(value)
    
    else:
      error("Unsupported kind: " & $node.kind)
  
proc isDefiningProc(node: NimNode): bool = node.kind in [nnkProcDef]
  
macro registerRouteFor*(name: string, input: typed) =
  ## Registers a proc for handling messages as "server route" with threadButler.
  ## This is used for code-generation with `generate()`  
  input.expectKind(
    @[nnkProcDef, nnkSym], 
    fmt"""
      Tried to register `{strutils.strip(input.repr)}` as serverRoute with unsupported syntax!
      The following are supported:
        - proc myProc(msg: SomeType, hub: ChannelHub[X, Y]){"\{.registerRouteFor\: \"server\".\}"}
        - serverRoute(myProc)
    """.dedent(6)
  )
  let name: ThreadName = name.toThreadName()
  
  let procDef = input.getProcDef()  
  input.assertKind(nnkProcDef)
  addRoute(name, procDef)
  
  if input.isDefiningProc():
    result = input ## Necessary so that the defined proc does not "disappear"

  when defined(butlerDebug):
    echo fmt"Registered handler '{procDef.name}' for '{name.string}'"

proc isDefiningType(node: NimNode): bool = node.kind in [nnkTypeDef, nnkTypeSection, nnkStmtList]

proc extractTypeDefs(node: NimNode): seq[NimNode] =
  node.assertKind(@[nnkSym, nnkStmtList])

  case node.kind:
    of nnkSym:
      let typeDef = node.getImpl()
      typeDef.assertKind(nnkTypeDef)
      result.add(typeDef)
      
    of nnkStmtList:
      for subNode in node:
        
        case subNode.kind:
          of nnkTypeDef:
            result.add(subNode)
            
          of nnkTypeSection:
            for subSubNode in subNode:
              subSubNode.assertKind(nnkTypeDef)
              result.add(subSubNode)
              
          else:
            error(fmt"'typ' macro does not support inner node of kind '{subNode.kind}'")
    else:
      error(fmt"'typ' macro does not support kind '{node.kind}'")
    

macro registerTypeFor*(name: string, input: typed) =
  ## Registers a type of a message for a given thread with threadButler.
  ## This is used for code-generation with `generate()`
  input.expectKind(
    @[nnkSym, nnkStmtList], 
    fmt"""
      Tried to register `{strutils.strip(input.repr)}` as type with unsupported syntax!
      The following are supported:
        - registerTypeFor("someName", SomeType)
        - registerTypeFor("someName"):
            type SomeType = <Your Type declaration>
        - registerTypeFor("someName"):
            type 
              OtherType = <Second Type declaration>
              ThirdType = <Third Type declaration>
    """.dedent(6)
  )
  let name: ThreadName = name.toThreadName()
    
  for typeDef in input.extractTypeDefs():
    name.addType(typeDef)
  
  if input.isDefiningType(): 
    result = input  ## Necessary so that the defined type does not "disappear"

  when defined(butlerDebug):
    let typeNames = input.extractTypeDefs().mapIt($it[0])
    echo fmt"Registered types '{typeNames}' for '{name.string}'"

proc asEnum(name: ThreadName): NimNode =
  ## Generates an enum type `enumName` with all keys in `routes` turned into enum values.
  let types = name.getTypes()
  let hasTypes = types.len > 0
  
  let enumFields: seq[NimNode] = if not hasTypes:
      @[ident("none")] # Fallback when no message type is provided
    else:
      name.getTypes().mapIt(ident(it.kindName))
  
  return newEnum(
    name = ident(name.enumName), 
    fields = enumFields, 
    public = true,
    pure = true
  )

proc asVariant(name: ThreadName): NimNode =
  ## Generates an object variant type `typeName` using the enum called `enumName`.
  ## Each variation of the variant has 1 field. 
  ## The type of that field is the message type stored in the NimNode in `routes`.
  ## Returns a simple object type with no fields if no routes are registered
  if not name.hasTypes():
    let typeName = newIdentNode(name.variantName)
    return quote do:
      type `typeName` = ref object 

  let caseNode = nnkRecCase.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("kind"),
      newIdentNode(name.enumName),
      newEmptyNode()
    )
  )
  
  for typ in name.getTypes():
    typ.assertKind(nnkTypeDef)
    let branchNode = nnkOfBranch.newTree(
      newIdentNode(typ.kindName),
      nnkRecList.newTree(
        newIdentDefs(
          newIdentNode(typ.fieldName),
          ident(typ.typeName)
        ) 
      )
    )
    
    caseNode.add(branchNode)
  
  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      postfix(newIdentNode(name.variantName), "*"),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree( caseNode )
      )
    )
  )
  
proc genMessageRouter*(name: ThreadName): NimNode =
  ## Generates "proc routeMessage(msg: `msgVariantTypeName`, hub: ChannelHub)".
  ## `msgVariantTypeName` must be the name of an object variant type.
  ## The procs body is a gigantic switch-case statement over all kinds of `msgVariantTypeName`

  result = newProc(name = postfix(ident("routeMessage"), "*"))
  let genericParams = nnkGenericParams.newTree(
    nnkIdentDefs.newTree(
      newIdentNode("SMsg"),
      newIdentNode("CMsg"),
      newEmptyNode(),
      newEmptyNode()
    )
  )
  result[2] = genericParams # 2 = Proc Node for generic params
  
  let msgParamName = "msg"
  let msgParam = newIdentDefs(ident(msgParamName), ident(name.variantName))
  result.params.add(msgParam)
  
  let hubParam = newIdentDefs(
    ident("hub"), 
    nnkBracketExpr.newTree(
      ident("ChannelHub"),
      ident("SMsg"),
      ident("CMsg")
    )
  )
  result.params.add(hubParam)
  
  let hasEmptyMessageVariant = not name.hasTypes()
  if hasEmptyMessageVariant:
    result.body = nnkDiscardStmt.newTree(newEmptyNode())
    return
  
  let caseStmt = nnkCaseStmt.newTree(
    newDotExpr(ident(msgParamName), ident("kind"))
  )
  
  for handlerProc in name.getRoutes():
    # Generates proc call `<routeName>(<msgParamName>.<fieldName>, hub)`
    let firstParamType = handlerProc.firstParamType
    let handlerCall = nnkCall.newTree(
      handlerProc.name,
      newDotExpr(ident(msgParamName), ident(firstParamType.fieldName)),
      ident("hub")
    )
    
    # Generates `of <routeName>: <handlerCall>`
    let branchNode = nnkOfBranch.newTree(
      ident(firstParamType.kindName),
      newStmtList(handlerCall)
    )
    
    caseStmt.add(branchNode)
    
  result.body.add(caseStmt)

proc genSenderProc*(name: ThreadName, typ: NimNode): NimNode =
  ## Generates a procedure to send messages to the server via ChannelHub and hiding the object variant.
  typ.assertKind(nnkTypeDef)
  
  let procName = newIdentNode("sendMessage")
  let msgType = newIdentNode(typ.typeName)
  let variantType = newIdentNode(name.variantName)
  let msgKind = newIdentNode(typ.kindName)
  let variantField = newIdentNode(typ.fieldName)
  let senderProcName = newIdentNode(channelHub.SEND_PROC_NAME) # This string depends on the name 
  
  quote do:
    proc `procName`*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: `msgType`): bool =
      let msgWrapper: `variantType` = `variantType`(kind: `msgKind`, `variantField`: msg)
      return hub.`senderProcName`(msgWrapper)

proc addTypeCode*(
  node: NimNode, 
  name: ThreadName, 
) =
  ## Adds the various pieces of code that need to be generated to the output
  let messageEnum = name.asEnum()
  node.add(messageEnum)
  
  let messageVariant = name.asVariant()
  node.add(messageVariant)

proc generateCode*(name: ThreadName): NimNode =
  result = newStmtList()
  
  result.addTypeCode(name)
  result.add(name.genMessageRouter())
  
  for typ in name.getTypes():
    result.add(genSenderProc(name, typ))

macro generate*(name: string): untyped =
  let name: ThreadName = name.toThreadName()

  result = name.generateCode()

  when defined(butlerDebug):
    echo result.repr