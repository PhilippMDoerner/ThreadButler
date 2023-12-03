import std/[strformat, options]
import ./log

type ChannelHub*[SMsg, CMsg] = ref object
  serverChannel: Channel[SMsg]
  clientChannel: Channel[CMsg]

proc new*[SMsg, CMsg](t: typedesc[ChannelHub[SMsg, CMsg]]): ChannelHub[SMsg, CMsg] =
  result = ChannelHub[SMsg, CMsg]()
  result.serverChannel.open()
  result.clientChannel.open()
  
proc destroy*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]) =
  hub.serverChannel.close()
  hub.clientChannel.close()

proc sendMsgToServer*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: CMsg): bool =
  debug fmt"send client => server: {msg.repr}"
  hub.clientChannel.trySend(msg)
  
proc sendMsgToClient*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: SMsg): bool =
  debug fmt"send client <= server: {msg.repr}"
  hub.serverChannel.trySend(msg)

proc readClientMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]): Option[CMsg] =
  let response: tuple[dataAvailable: bool, msg: CMsg] = hub.clientChannel.tryRecv()
  
  result = if response.dataAvailable:
      debug fmt"read client => server: {response.msg.repr}"
      some(response.msg)
    else:
      none(CMsg)

proc readServerMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]): Option[SMsg] =
  let response: tuple[dataAvailable: bool, msg: SMsg] = hub.serverChannel.tryRecv()

  result = if response.dataAvailable:
      debug fmt"read client <= server: {response.msg.repr}"
      some(response.msg)
    else:
      none(SMsg)
  
proc hasServerMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]): bool =
  hub.serverChannel.peek() > 0
  
proc hasClientMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]): bool =
  hub.serverChannel.peek() > 0