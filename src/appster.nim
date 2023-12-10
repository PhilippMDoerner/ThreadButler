import std/[options, os]
import ./appster/[typegen, communication, events, log]

export typegen
export communication
export events

type KillError = object of CatchableError
proc shutdownServer*() =
  ## Triggers the shut down of the server
  raise newException(KillError, "Shutdown")
  
type ServerData*[SMsg, CMsg] = object
  hub*: ChannelHub[SMsg, CMsg]
  sleepMs*: int # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
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
      let msg: Option[SMsg] = data.hub.readMsg(SMSg)
      if msg.isSome():
        try:
          routeMessage(msg.get(), data.hub)
        
        except KillError:
          break
        
        except Exception as e:
          log.warn("Encountered Exception: " & e.repr)

      sleep(data.sleepMs)
  
    data.shutDown.execEvents()

  createThread(result, serverLoop, data)
