import std/[options, os, logging]
import ./appster/[typegen, communication, events]

export typegen
export communication
export events

type Server*[SMsg, CMsg] = Thread[ChannelHub[SMsg, CMsg]]

type Appster*[SMsg, CMsg] = object
  server: Server[SMsg, CMsg]
  channels: ChannelHub[SMsg, CMsg]
  
type ServerData*[SMsg, CMsg] = object
  # loggers*: seq[Logger]
  hub*: ChannelHub[SMsg, CMsg]
  sleepMs*: int
  startUp*: seq[Event]
  shutDown*: seq[Event]

proc runServer*[SMsg, CMsg](
  data: var ServerData[SMsg, CMsg]
): Thread[ServerData[SMsg, CMsg]] =
  mixin routeMessage

  proc serverLoop(data: ServerData[SMsg, CMsg]) {.gcsafe.}=
    
    while true:
      let msg = data.hub.readClientMsg()
      if msg.isSome():
        routeMessage(msg.get(), data.hub)

      sleep(1) # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
  
  createThread(result, serverLoop, data)
