import std/[macros, macrocache, sequtils, strformat]
import ./utils

type ThreadName* = string

const types = CacheTable"typeTable"
## Stores a list of types for a given "threadServer" based on a given name
## The procs are stored in a StatementList-NimNode for later retrieval,
## turning this effectively in a complicated Version of CacheTable[string, CacheSeq]

const routes = CacheTable"routeTable" ##
## Stores a list of procs for a given "threadServer" based on a given name
## The procs are stored in a StatementList-NimNode for later retrieval,
## turning this effectively in a complicated Version of CacheTable[string, CacheSeq]

proc typeName(node: NimNode): string =
  node.assertKind(nnkTypeDef)
  return $node[0]

proc firstParamType(node: NimNode): NimNode =
  node.assertKind(nnkProcDef)
  let firstParam = node.params[1]
  let typeNode = firstParam[1]
  case typeNode.kind:
    of nnkTypeDef: return typeNode
    of nnkSym: return typeNode.getImpl()
    else: error("This type of message type is not supported")

proc getRoutes*(name: ThreadName): seq[NimNode] =
  let hasRoutes = routes.hasKey(name)
  if not hasRoutes:
    return @[]
  
  for route in routes[name]:
    result.add(route)

proc getTypes*(name: ThreadName): seq[NimNode] =
  let hasTypes = types.hasKey(name)
  if not hasTypes:
    return @[]
  
  for typ in types[name]:
    result.add(typ)


proc hasTypeOfName*(name: ThreadName, typName: string): bool =
  for typ in name.getTypes():
    if typ.typeName() == typName:
      return true
  
  return false

proc getTypeOfName*(name: ThreadName, typName: string): NimNode =
  for typ in name.getTypes():
    if typ.typeName() == typName:
      return typ
  
  return newEmptyNode()

proc addType*(name: ThreadName, typeDef: NimNode) =
  typeDef.assertKind(nnkTypeDef, "You need a type definition to store a type")
  let isFirstType = not types.hasKey(name)
  if isFirstType:
    types[name] = newStmtList()
  
  let typeName = typeDef.typeName()
  let isAlreadyRegistered = name.hasTypeOfName(typeName)
  if isAlreadyRegistered:
    let otherType = name.getTypeOfName(typeName)
    error(fmt"Failed to register '{typeName}' from {typeDef.lineInfo}. A type with that name was already registered (see: {otherType.lineInfo})")
  
  types[name].add(typeDef)

proc validateRoute(name: ThreadName, procDef: NimNode) =
  procDef.assertKind(nnkProcDef)
  let firstParamTypeName = procDef.firstParamType.typeName
  
  if not name.hasTypeOfName(firstParamTypeName):
    error(fmt"Failed to register proc '{procDef.name}'. No matching type '{firstParamTypeName}' has been registered.")

proc addRoute*(name: ThreadName, procDef: NimNode) =
  ## Stores a proc definition as "route" in `routes`.
  procDef.assertKind(nnkProcDef, "You need a proc definition to add a route in order to extract the first parameter")
  
  validateRoute(name, procDef)
  
  let isFirstRoute = not routes.hasKey(name)
  if isFirstRoute:
    routes[name] = newStmtList()
  
  routes[name].add(procDef)
    
proc hasRoutes*(name: string): bool =
  name.getRoutes().len > 0

proc getRegisteredThreadnames*(): seq[string] =
  for key, _ in routes:
    result.add(key)

proc debugContent*() =
  echo "Debug"
  for key, _ in routes:
    echo key, " - ", routes[key].len