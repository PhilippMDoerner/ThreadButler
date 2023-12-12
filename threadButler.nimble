# Package

version       = "0.1.0"
author        = "Philipp Doerner"
description   = "Use threads as if they were servers/microservices to enable multi-threading with a simple mental model."
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"

# Example-Dependencies
requires "owlkettle#head"

import std/[strutils, strformat, sequtils]

proc isNimFile(path: string): bool = path.endsWith(".nim")
proc isExampleFile(path: string): bool = 
  let file = path.split("/")[^1]
  return file.startsWith("ex_")

proc findExamples(path: string): seq[string] =
  for file in listFiles(path):
    if file.isNimFile() and file.isExampleFile():
      result.add(file)
      
  for dir in listDirs(path):
    result.add(findExamples(dir))

task example, "run a single example from the examples directory":
  let params = commandLineParams.filterIt(it.startsWith("-")).join(" ")
  let fileName = commandLineParams[^1]
  
  let command = fmt"nim r {params} examples/{fileName}.nim"
  echo "Command: ", command
  exec command

task examples, "compile all examples":
  let params = commandLineParams.filterIt(it.startsWith("-")).join(" ")

  for file in findExamples("./examples"):
    let command = fmt"nim c {params} {file}"
    echo "INFO: Compile ", command
    exec command
    
    echo "INFO: OK"
    echo "================================================================================"

task exampleList, "list all available examples":
  for file in findExamples("./examples"):
    echo file
    
task docs, "Generate the nim docs":
  exec"nim doc --outdir:./docs/htmldocs/threadButler/integrations --index:on ./src/threadButler/integration/owlButler.nim"
  exec"nim doc --outdir:./docs/htmldocs/threadButler/integrations --index:on ./src/threadButler/integration/owlCodegen.nim"
  exec"nim doc --project --index:on --outdir:./docs/htmldocs src/threadButler.nim"