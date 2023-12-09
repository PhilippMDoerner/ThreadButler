import std/[macros, macrocache, strformat, strutils, tables]
import ./utils

const routes = CacheTable"routeTable" ##
## Stores a list of procs for a given "threadServer" based on a given name
## The procs are stored in a StatementList for later retrieval,
## turning this effectively in a complicated Version of CacheTable[string, CacheSeq]

const msgTypes = CacheTable"msgTypes"

proc addRoute*(name: string, procDef: NimNode) =
  ## Stores a proc definition as "route" in `routes`.
  procDef.assertKind(nnkProcDef, "You need a proc definition to add a route in order to extract the first parameter")
  echo "Adding route for: ", name
  let procName: string = $procDef.name
  let isFirstRoute = not routes.hasKey(name)
  if isFirstRoute:
    routes[name] = newStmtList()
  
  routes[name].add(procDef)
  
proc getRoutes*(name: string): seq[NimNode] =
  let hasRoutes = routes.hasKey(name)
  if not hasRoutes:
    return @[]
  
  for route in routes[name]:
    result.add(route)
    
proc hasRoutes*(name: string): bool =
  name.getRoutes().len > 0

proc debugContent*() =
  echo "Debug"
  for key, _ in routes:
    echo key, " - ", routes[key].len