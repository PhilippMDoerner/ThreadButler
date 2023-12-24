##[
  Defines procs for various validation stpes within threadButler.
  Mostly related to compile-time validation of macros.
  
  This module is only intended for use within threadButler and for integrations.
]##
import std/[strformat, sets, macros, options, sequtils, strutils]
import ./register
import ./utils
import ./types

proc raiseRouteValidationError(procDef: NimNode, msg: string) =
  error(fmt"""
    Failed to register proc '{procDef.name}' from '{procDef.lineInfo}'. {msg}
    Proc: {procDef.repr}
  """.dedent(2))

proc validateMsgType*(name: ThreadName, procDef: NimNode) =
  ## Validates for a route `procDef` that the message type it gets called with
  ## is also a type registered with threadButler.
  procDef.assertKind(nnkProcDef)

  let firstParamTypeName = procDef.firstParamType.typeName
  if not name.hasTypeOfName(firstParamTypeName):
    raiseRouteValidationError(procDef, fmt"No matching type '{firstParamTypeName}' has been registered for '{name.string}'.")

proc validateFreeType*(name: ThreadName, procDef: NimNode) =
  ## Validates for a route `procDef` that the message type it gets called with
  ## is not already registered with another route.
  procDef.assertKind(nnkProcDef)
  let firstParamTypeName = procDef.firstParamType.typeName

  let procForType = getProcForType(name, firstParamTypeName)
  let isAlreadyRegistered = procForType.isSome()
  if isAlreadyRegistered:
    raiseRouteValidationError(procDef, fmt"A handler proc for type '{firstParamTypeName}' has already been registered for '{name.string}' at '{procForType.get().lineInfo}'")

proc validateAllTypesHaveHandlers*(name: ThreadName) =
  let routeMsgTypeNames = name.getRoutes().mapIt(it.firstParamType().typeName()).toHashSet()
  for typ in name.getTypes():
    if typ.typeName() notin routeMsgTypeNames:
      error(fmt"""
        Incorrect threadServer definition '{name.string}'.
        The message type '{typ.typeName()}' was registered for thread '{name.string}' but no handler for it was registered!
      """.dedent(8))

proc validateParamCount*(name: ThreadName, procDef: NimNode, expectedParamCount: int) =
  procDef.assertKind(nnkProcDef)

  let paramCount = procDef.params.len() - 1
  if paramCount != expectedParamCount:
    raiseRouteValidationError(procDef, fmt"Handler proc did not have '{expectedParamCount}' parameters, but '{paramCount}'. Handler procs must follow the pattern `proc <procName>(msg: <YourMsgType>, hub: ChannelHub)`")

proc validateChannelHubParam*(name: ThreadName, procDef: NimNode, expectedHubParamPosition: int) =
  procDef.assertKind(nnkProcDef)
  
  let hubParam = procDef.params[expectedHubParamPosition]
  let hubParamTypeName = $hubParam[1]
  let isChannelHubType = hubParamTypeName == "ChannelHub" 
  if not isChannelHubType:
    raiseRouteValidationError(procDef, fmt"Handler proc parameter {expectedHubParamPosition} was not `ChannelHub` even though it was")

proc sectionErrorText(name: ThreadName): string = fmt"""
  Failed to parse actor '{name.string}' messageType/handler blocks.
  Expected syntax of:
    messageType:
      Type1
      Type2
      ...
      
    handlers:
      proc handler1(msg: Type1, hub: ChannelHub) =
        <Implementation>
      
      proc handler2(msg: Type2, hub: ChannelHub) = 
        <Implementation>
      
      ...
"""

proc validateRoute(name: ThreadName, procDef: NimNode) =
  procDef.assertKind(nnkProcDef)
  
  validateMsgType(name, procDef)
  validateFreeType(name, procDef)
  validateParamCount(name, procDef, expectedParamCount = 2)
  validateChannelHubParam(name, procDef, expectedHubParamPosition = 2)

proc validateRoute(
  name: ThreadName, 
  procDef: NimNode,
  expectedParamCount: int,
  expectedHubParamPosition: int
) =
  procDef.assertKind(nnkProcDef)
  
  validateMsgType(name, procDef)
  validateFreeType(name, procDef)
  validateParamCount(name, procDef, expectedParamCount)
  validateChannelHubParam(name, procDef, expectedHubParamPosition)


proc validateTypeSection*(name: ThreadName, typeSection: NimNode) =
  typeSection.assertKind(nnkStmtList, sectionErrorText(name))
  
  for typeDef in typeSection:
    typeDef.assertKind(nnkIdent)
        
proc validateHandlerSection*(
  name: ThreadName, 
  handlerSection: NimNode,
  expectedParamCount: int = 2, 
  expectedHubParamPosition: int = 2
) =
  handlerSection.assertKind(nnkStmtList, sectionErrorText(name))

  for handlerDef in handlerSection:
    handlerDef.assertKind(nnkProcDef)
    validateRoute(name, handlerDef, expectedParamCount, expectedHubParamPosition)
  
proc validatePropertiesSection*(name: ThreadName, propertySection: NimNode) =
  propertySection.assertKind(nnkStmtList, sectionErrorText(name))
  
  for propertyNode in propertySection:
    propertyNode.assertKind(@[nnkAsgn, nnkCall])
    let propertyName = $propertyNode[0]
    if propertyName notin PROPERTY_NAMES:
      error(fmt"Invalid property name '{propertyName}'. Only the following properties are allowed: '{PROPERTY_NAMES}'")

proc validateSectionNames*(body: NimNode) =
  let sectionParents: seq[NimNode] = body.getNodesOfKind(nnkCall)
  let sectionNames = sectionParents.mapIt($it[0])
  for name in sectionNames:
    let isValidSectionName = name in SECTION_NAMES
    if not isValidSectionName:
      error(fmt"Invalid section name '{name}'. Only the following sections are allowed: '{SECTION_NAMES}'")