import std/[options, os, logging]
import ./appster/[typegen, communication, events, log]

export typegen
export communication
export events

type KillError = object of CatchableError
proc shutdownServer*() =
  raise newException(KillError, "Shutdown")

type Server*[SMsg, CMsg] = Thread[ChannelHub[SMsg, CMsg]]
  
type ServerData*[SMsg, CMsg] = object
  # loggers*: seq[Logger]
  hub*: ChannelHub[SMsg, CMsg]
  sleepMs*: int
  startUp*: seq[Event]
  shutDown*: seq[Event]

proc execStartupEvents[SMSg, CMsg](data: ServerData[SMSg, CMsg]) =
  for event in data.startUp:
    event.exec()

proc runServer*[SMsg, CMsg](
  data: var ServerData[SMsg, CMsg]
): Thread[ServerData[SMsg, CMsg]] =
  mixin routeMessage

  proc serverLoop(data: ServerData[SMsg, CMsg]) {.gcsafe.}=
    data.startUp.execEvents()
    
    while true:
      let msg = data.hub.readClientMsg()
      if msg.isSome():
        try:
          routeMessage(msg.get(), data.hub)
        
        except KillError:
          break
        
        except Exception as e:
          log.warn("Encountered Exception: " & e.repr)

      sleep(1) # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
  
    data.shutDown.execEvents()

  createThread(result, serverLoop, data)
