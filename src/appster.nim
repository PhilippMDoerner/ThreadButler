import std/os
import ./appster/[typegen, communication]

export typegen
export communication

type Server*[SMsg, CMsg] = Thread[ChannelHub[SMsg, CMsg]]

type Appster*[SMsg, CMsg] = object
  server: Server[SMsg, CMsg]
  channels: ChannelHub[SMsg, CMsg]

proc runServer*[SMsg, CMsg](sleepMs: int = 0): Appster[SMsg, CMsg] =
  mixin handleClientMessage
  let channels = new(ChannelHub[SMsg, CMsg])
  
  proc serverLoop(hub: ChannelHub[SMsg, CMsg]) =
    while true:
      let msg = hub.readClientMsg()
      if msg.isSome():
        handleClientMessage(hub, msg)
        discard hub.sendToClient("Received Message ")

      sleep(sleepMs) # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
  
  return Appster[SMsg, CMsg](
    server: createThread(result, serverLoop, channels),
    channels: channels
  )

## Next Step:
## - Write a first client to run with an Appster Server
## - Actually generate handle<X>Message procs instead of the dummies that are there right now

# Dummy code

when isMainModule:
  type Message1 = object
    name: string
  type Message2 = object


  proc handleMessage1(msg: Message1, hub: ChannelHub[string, string]) = echo "Message1"
  proc handleMessage2(msg: Message2, hub: ChannelHub[string, string]) {.serverRoute.} = 
    echo "Message2"

  clientRoute(handleMessage1)
  clientRoute(handleMessage2)
  serverRoute(handleMessage1)
  generate()

  import std/sequtils

  let hub = new(ChannelHub[string, string])
  let msg = ServerMessage(kind: handleMessage2Kind, handleMessage2Msg: Message2())
  routeMessage(msg, hub)