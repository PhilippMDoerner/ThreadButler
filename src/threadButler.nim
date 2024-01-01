import std/[options, tables, asyncdispatch]
import ./threadButler/[types, codegen, channelHub, events, log]
import chronicles
export chronicles
##[  
  .. importdoc:: threadButler/integrations/owlButler
  
  This package provides a way to set-up multithreading with
  multiple long-running threads that talk to one another via
  message passing. 
  
  The architecture is modeled after a client-server architecture 
  between threads, with one thread running the GUI loop and one 
  or more other threads acting running their own event-loops, 
  listening for messages and acting as backend "servers".
  
  Threadbutler groups message-types and handler procs defining 
  what to do with a given message-type into a single thread.
  It then defines one overarching message-variant that encompasses
  all messages that are allowed to be sent to that thread. 
  
  For integration utilities with other frameworks see:
    * `createListenerEvent`_
]##

export 
  codegen.threadServer,
  codegen.prepareServers
export channelHub
export events
export types.Server

type KillError* = object of CatchableError ## A custom error. Throwing this will gracefully shut down the server

var IS_RUNNING* = true ## \
## Global switch that controls whether threadServers keep running or shut down.
## Change this value to false to trigger shut down of all threads running
## ThreadButler default event-loops.

proc sleeper*() {.async.} =
  ## Enables using poll without raising ValueErrors by
  ## registering an endless timer in the thread.
  while IS_RUNNING:
    await sleepAsync 10000

proc shutdownServer*() =
  ## Triggers the graceful shut down of the thread-server this proc is called on.
  raise newException(KillError, "Shutdown")
  

proc runServerLoop[Msg](data: Server[Msg]) {.gcsafe.} =
  mixin routeMessage

  while IS_RUNNING:
    var msg: Option[Msg] = data.hub.readMsg(Msg)
    try:
      while msg.isSome():
        {.gcsafe.}:
          routeMessage(msg.get(), data.hub)

        msg = data.hub.readMsg(Msg)

    except KillError:
      break
    
    except CatchableError as e:
      error "Message caused exception", msg, error = e.repr
    
    poll(data.sleepMs)
  
proc serverProc*[Msg](data: Server[Msg]) {.gcsafe.} =
  mixin runServerLoop
  data.startUp.execEvents()

  discard sleeper() 
  runServerLoop[Msg](data)
  
  data.shutDown.execEvents()

proc run[Msg](thread: var Thread[Server[Msg]], data: Server[Msg]) =
  when not defined(butlerDocs):
    system.createThread(thread, serverProc[Msg], data)

template withServer*(hub: ChannelHub, threadName: static string, body: untyped) =
  ## Spawns the server on the thread associated with `threadName`.
  ## 
  ## The server listens for new messages and executes `routeMessage` for every message received,
  ## which will call the registered handler proc for this message type.
  ## startup and shutdown events in `data` are executed before and after the event-loop of the server.
  ## 
  ## Sends message to shut the server down gracefully and waits for shutdown 
  ## to complete once the code in `body` has finished executing.
  mixin sendKillMessage
  let server = initServer(hub, threadName.toVariantType())

  run[threadName.toVariantType()](threadName.toThreadVariable(), server)
  
  body
  
  server.hub.sendKillMessage(threadName.toVariantType())
  when not defined(butlerDocs):
    joinThread(threadName.toThreadVariable())

proc send*[Msg](server: Server[Msg], msg: auto): bool =
  ## Utility proc to allow sending messages directly from a server object.
  server.hub.sendMessage(msg)