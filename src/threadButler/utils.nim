import std/[terminal, strformat, macros, sequtils]

##[
  Defines utilities for making validation of individual steps in code-generation easy.
  
  This module is only intended for use within threadButler and for integrations.
]##

proc assertKind*(node: NimNode, kind: seq[NimNodeKind], msg: string = "") =
  ## Custom version of expectKind, uses doAssert which can never be turned off.
  ## Use this throughout procs to validate that the nodes they get are of specific kinds.
  ## Also enables custom error messages.
  let boldCode = ansiStyleCode(styleBright)
  let msg = if msg == "": fmt"{boldCode} Expected a node of kind '{kind}', got '{node.kind}'" else: msg
  let errorMsg = msg & "\nThe node: " & node.repr & "\n" & node.treeRepr
  doAssert node.kind in kind, errorMsg

proc assertKind*(node: NimNode, kind: NimNodeKind, msg: string = "") =
  assertKind(node, @[kind], msg)

proc expectKind*(node: NimNode, kinds: seq[NimNodeKind], msg: string) =
  ## Custom version of expectKind, uses "error" which can be turned off.
  ## Use this within every macro to validate the user input
  ## Also enforces custom error messages to be helpful to users.
  if node.kind notin kinds:
    let boldCode = ansiStyleCode(styleBright)
    let msgEnd = fmt"Caused by: Expected a node of kind in '{kinds}', got '{node.kind}'"
    let errorMsg = boldCode & msg & "\n" & msgEnd
    error(errorMsg)
    
proc getNodesOfKind*(node: NimNode, nodeKind: NimNodeKind): seq[NimNode] =
  ## Recursively traverses the AST in `node` and returns all nodes of the given
  ## `nodeKind`.
  for childNode in node.children:
    let isDesiredNode = childNode.kind == nodeKind
    if isDesiredNode:
      result.add(childNode)
    else:
      let desiredChildNodes: seq[NimNode] = getNodesOfKind(childNode, nodeKind)
      result.add(desiredChildNodes)

proc isAsyncProc*(procDef: NimNode): bool =
  ## Checks if a given procDef represents an async proc
  procDef.assertKind(nnkProcDef)

  let resultType = procDef.params[0]
  let pragmaNodes: seq[NimNode] = procDef.getNodesOfKind(nnkPragma)
  return case pragmaNodes.len:
    of 0:
      false
    else:
      let pragmaNames = pragmaNodes[0].mapIt($it)
      pragmaNames.anyIt(it == "async")
      