import std/[options, os]
import ./appster/[typegen, communication]

export typegen
export communication

type Server*[SMsg, CMsg] = Thread[ChannelHub[SMsg, CMsg]]

type Appster*[SMsg, CMsg] = object
  server: Server[SMsg, CMsg]
  channels: ChannelHub[SMsg, CMsg]

proc runServer*[SMsg, CMsg](sleepMs: int = 0, channels: ChannelHub[SMsg, CMsg] ): Thread[ChannelHub[SMsg, CMsg]] =
  mixin routeMessage

  proc serverLoop(hub: ChannelHub[SMsg, CMsg]) =
    while true:
      let msg = hub.readClientMsg()
      if msg.isSome():
        routeMessage(msg.get(), hub)

      sleep(1) # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
  
  createThread(result, serverLoop, channels)


when isMainModule:
  type S2CMessage = object
    name: string
  type C2SMessage = object
  
  proc handleServerToClientMessage(msg: S2CMessage, hub: auto) {.clientRoute.} = 
    echo "On Client: Got Msg from Server!"
  proc handleClientToServerMessage(msg: C2SMessage, hub: auto) {.serverRoute.} = 
    echo "On Server: Got Msg from Client!"

  generate()

  proc main() =
    let channels = new(ChannelHub[ServerMessage, ClientMessage])
    let thread = runServer[ServerMessage, ClientMessage](0, channels)
    # echo "after server instantiation"
    discard channels.sendToServer(C2SMessage())
    joinThread(thread)
  
  main()