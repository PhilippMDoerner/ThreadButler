import std/[strformat, options, tables]
import ./log

type ChannelHub* = ref object
  channels*: Table[pointer, pointer]
  
proc addChannel*[Msg](hub: ChannelHub, t: typedesc[Msg]) =
  let key: pointer = default(Msg).getTypeInfo()
  var channel {.global.}: Channel[Msg]
  channel.open
  hub.channels[key] = channel.addr
  debug fmt"Added: {$t} - {cast[uint64](channel.addr)}"

proc getChannel*[Msg](hub: ChannelHub, t: typedesc[Msg]): var Channel[Msg] =
  let key: pointer = default(t).getTypeInfo()
  return cast[ptr Channel[Msg]](hub.channels[key])[]
  
proc debugLog[Msg](msg: Msg, hub: ChannelHub, success: bool) =
  let channelPtr = cast[uint64](hub.getChannel(Msg).addr)
  debug fmt"send {getThreadId()} => {channelPtr}: {msg.repr}"

const SEND_PROC_NAME* = "sendMsgToChannel"
proc sendMsgToChannel*[Msg](hub: ChannelHub, msg: Msg): bool =
  let success = hub.getChannel(Msg).trySend(msg)
  debugLog(msg, hub, success)
  return success

proc debugReadLog[Msg](msg: Msg, hub: ChannelHub) =
  let channelPtr = cast[uint64](hub.getChannel(Msg).addr)
  debug fmt"read {getThreadId()} <= {channelPtr}: {msg.repr}"

proc readMsg*[Msg](hub: ChannelHub, resp: typedesc[Msg]): Option[Msg] =
  var channel = hub.getChannel(Msg)
  
  let response: tuple[dataAvailable: bool, msg: Msg] = hub.getChannel(Msg).tryRecv()
  
  result = if response.dataAvailable:
      debugReadLog(response.msg, hub)
      some(response.msg)
    else:
      none(Msg)

proc hasMsg*[Msg](hub: ChannelHub): bool =
  hub.getChannel(Msg).peek() > 0
