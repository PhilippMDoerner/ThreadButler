import std/[options, os]
import ./threadButler/[codegen, channelHub, events, log]

export 
  codegen.generateTypes, 
  codegen.registerRouteFor,
  codegen.registerTypeFor,
  codegen.generateRouter
export channelHub
export events

type KillError = object of CatchableError
proc shutdownServer*() =
  ## Triggers the shut down of the server
  raise newException(KillError, "Shutdown")
  
type ServerData*[Msg] = object
  hub*: ChannelHub
  msgType*: Msg
  sleepMs*: int # Reduces stress on CPU when idle, increase when higher latency is acceptable for better idle efficiency
  startUp*: seq[Event]
  shutDown*: seq[Event]


## TODO: Got to think here, how do you figure out for a given server what object variant they're associated with?
proc runServer*[Msg](data: ServerData[Msg]): Thread[ServerData[Msg]] =
  mixin routeMessage

  proc serverLoop(data: ServerData[Msg]) {.gcsafe.}=
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
