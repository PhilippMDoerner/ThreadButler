# Package

version       = "0.1.0"
author        = "Philipp Doerner"
description   = "A simple application server for applications to offload their heavy computation to."
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
import std/[strutils, strformat, sequtils]

task example, "run a single example from the examples directory":
  let params = commandLineParams.filterIt(it.startsWith("-")).join(" ")
  let fileName = commandLineParams[^1]
  
  let command = fmt"nim r {params} examples/{fileName}.nim"
  echo "Command: ", command
  exec command
  
task exampleList, "list all available examples":
  for file in listFiles("./examples"):
    if file.endsWith(".nim"):
      var fileName = file
      fileName.removePrefix("examples/")
      fileName.removeSuffix(".nim")
      echo fileName