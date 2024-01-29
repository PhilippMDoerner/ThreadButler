# Package

version       = "0.1.0"
author        = "Philipp Doerner"
description   = "Use threads as if they were servers/microservices to enable multi-threading with a simple mental model."
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
requires "taskpools >= 0.0.5"
requires "chronicles >= 0.10.3"
when defined(butlerThreading):
  requires "threading#head"
  
when defined(butlerLoony):
  requires "https://github.com/nim-works/loony.git >= 0.1.12"

# Dev Dependencies
requires "https://github.com/disruptek/balls#v4"

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

proc echoSeparator() =
  echo "=".repeat(100)

task example, "run a single example from the examples directory":
  let params = commandLineParams.filterIt(it.startsWith("-")).join(" ")
  let fileName = commandLineParams.filterIt(it.endsWith(".nim"))[0]
  for example in findExamples("./examples"):
    if example.endsWith(fileName):
      let command = fmt"nim r {params} {example}"
      echo "Command: ", command
      exec command
      break

task examples, "compile all examples":
  let params = commandLineParams.filterIt(it.startsWith("-")).join(" ")
  let queues = @[
    ("std/system.Channels", ""),
    ("threading/channels.Chan", "-d:butlerThreading"),
    ("LoonyQueue", "-d:butlerLoony")
  ]
  
  for (title, queueFlag) in queues:
    echo fmt"INFO: ### COMPILE WITH {title} ###"
    for file in findExamples("./examples"):
      let command = fmt"nim c {queueFlag} {params} {file}"
      echo "INFO: Compile ", command
      exec command
      
      echo "INFO: OK"
      echoSeparator()
    echoSeparator()
    echo fmt"INFO: {title} - OK"
    echoSeparator()
    echoSeparator()

task exampleList, "list all available examples":
  for file in findExamples("./examples"):
    echo file
    
task docs, "Generate the nim docs":
  const outdir = "./docs/htmldocs"
  if dirExists(outdir): exec fmt"rm -r {outdir}"

  const outdirParam = fmt"--outdir:{outdir}"
  let paramSets = @[
    @[
      "--project",
      "--index:only",
      outdirParam,
      "src/threadButler.nim"
    ],
    @[
      "--index:on",
      fmt"{outdirParam}/threadButler/integrations",
      "src/threadButler/integration/owlButler.nim"
    ],
    @[
      "--index:on",
      fmt"{outdirParam}/threadButler/integrations",
      "src/threadButler/integration/owlCodegen.nim"
    ],
    @[
      "--project",
      "--index:on",
      outdirParam,
      "src/threadButler.nim"
    ]
  ]  
  
  for paramSet in paramSets:
    echoSeparator()
    let paramStr = paramSet.join(" ")
    let command = fmt"nim doc -d:butlerDocs --git.url:git@github.com:PhilippMDoerner/ThreadButler.git --git.commit:master --hints:off {paramStr}"
    echo "Command: ", command
    exec command
  
task benchmark, "Run the benchmark to check if there are performance differences between system.Channel and threading/channels.Chan":
  let file = "examples/ex_benchmark.nim"
  var params = @[
    "-d:release",
    "--warnings:off",
    "--hints:off",
    # "--define:butlerDebug",
    "-f",
    "-d:useMalloc",
    "-d:chronicles_enabled=off",
  ]
  let paramStr = params.join(" ")
  let command = fmt"nim r {paramStr} {file}"
  echoSeparator()
  
  echo fmt"INFO system.Channel: {command}"
  exec command
  
  params.add("--define:butlerThreading")
  let paramStr2 = params.join(" ")
  let command2 = fmt"nim r {paramStr2} {file}"
  
  echoSeparator()
  
  echo fmt"INFO threading/channel.Chan: {command2}"
  exec command

  echoSeparator()
  
task stress, "Runs the stress test permanently. For memory leak detection": 
  var params = @[
    "-d:release",
    "--warnings:off",
    "--hints:off",
    "--define:butlerDebug",
    "-f",
    "-d:useMalloc"
  ]
  let paramStr = params.join(" ")
  let command = fmt"nim r {paramStr} examples/stresstest.nim"
  echo fmt"INFO Running Stresstest: {command}"
  exec command

task tests, "Runs the test-suite":
  let params = @[
    "--mm:arc",
    "--mm:orc",
    "--cc:clang",
    "--debugger:native",
    "--threads:on",
    "-d:butlerThreading",
    "--passc:\"-fno-omit-frame-pointer\"",
    "--passc:\"-mno-omit-leaf-frame-pointer\"",
    "-d:chronicles_enabled=off",
    "-d:useMalloc",
  ]
  let paramsStr = params.join(" ")
  let command = fmt"balls {paramsStr}"
  echo command
  exec command
  
task runTest, "Runs a single test file with asan or tsan":
  let params = @[
    "--cc:clang",
    "--debugger:native",
    """--passc:"-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer" """,
    "-d:chronicles_enabled=off",
    "--threads:on",
    "-d:butlerThreading",
    "-d:danger",
    "-d:useMalloc",
  ]
  let paramsStr = params.join(" ")
  let file = commandLineParams[^1]
  
  for sanitizer in ["address", "thread"]:
    for memoryModel in ["arc", "orc"]:
      let command = fmt"""nim r --mm:{memoryModel} --passl:"-fsanitize={sanitizer}" --passc:"-fsanitize={sanitizer}" {paramsStr} tests/{file}"""
      echo command
      exec command

task nimidocs, "Compiles the nimibook docs":
  rmDir "docs/bookCompiled"
  exec "nimble install -y nimib@#head nimibook@#head"
  exec "nim c -d:release --mm:refc nbook.nim"
  exec "./nbook --mm:refc update"
  exec "cp -r ./assets ./docs/bookCompiled"
  exec "./nbook --path:./src -d:butlerDocs --mm:refc build"