import std/[options, os]
import ./threadButler/[codegen, channelHub, events, log]

##[
  .. importdoc:: threadButler/integrations/owlCodegen, threadButler/integrations/owlButler
  
  For integration utilities with other frameworks see:
    * [owlCodegen](./threadButler/integrations/owlButler.html)
]##

export 
  codegen.generateSetupCode, 
  codegen.registerRouteFor,
  codegen.registerTypeFor,
  codegen.generateRouters
export channelHub
export events

type KillError = object of CatchableError ## A custom error. Throwing this will gracefully shut down the server

proc shutdownServer*() =
  ## Triggers the graceful shut down of the thread-server this proc is called on.
  raise newException(KillError, "Shutdown")
  
type Server*[Msg] = object ## Data representing a single thread server
  hub*: ChannelHub
  msgType*: Msg
  sleepMs*: int ## Reduces stress on CPU when idle, increase when higher latency is acceptable for better idle efficiency
  startUp*: seq[Event] ## parameterless closures to execute before running the server
  shutDown*: seq[Event] ## parameterless closures to execute after when the server is shutting down


proc run*[Msg](data: Server[Msg]): Thread[Server[Msg]] =
  ## Runs a simple thread-server in a new thread.
  ## The server listens for new messages and executes `routeMessage` for every message received,
  ## which will call the registered handler proc for this message type.
  ## startup and shutdown events in `data` are executed here before and after the main-loop of the server.
  ## The server gracefully shuts down if `routeMessage` throws a `KillError`.
  mixin routeMessage

  proc serverLoop(data: Server[Msg]) {.gcsafe.} =
    data.startUp.execEvents()
    
    while true:
      let msg: Option[Msg] = data.hub.readMsg(Msg)
      if msg.isSome():
        try:
          routeMessage(msg.get(), data.hub)
        
        except KillError:
          break
        
        except Exception as e:
          log.error(fmt"Message '{msg.get().repr}' Caused exception: " & e.repr)

      sleep(data.sleepMs)
  
    data.shutDown.execEvents()

  system.createThread(result, serverLoop, data)

template withServer*[Msg](server: Server[Msg], body: untyped) =
  ## Spawns the server in the background.
  ## Sends message to shut the server down gracefully and waits for shutdown to complete.
  mixin sendKillMessage
  let thread: Thread[Server[Msg]] = server.run()
  
  body
  
  server.hub.sendKillMessage(Msg.type)
  joinThread(thread)
