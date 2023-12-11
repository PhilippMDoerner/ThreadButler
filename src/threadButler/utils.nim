import std/[terminal, strformat, macros]

## Defines utilities for making validation of individual steps in code-generation easy.

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