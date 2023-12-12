import std/[strformat, options, tables]
import ./log

type ChannelHub* = ref object
  channels*: Table[pointer, pointer]
  
proc addChannel*[Msg](hub: ChannelHub, t: typedesc[Msg]) =
  ## Instantiates and opens a `Channel` to `hub` specifically for type `Msg`.
  ## This associates it with `Msg`. 
  let key: pointer = default(Msg).getTypeInfo()
  var channel {.global.}: Channel[Msg]
  channel.open
  hub.channels[key] = channel.addr
  notice fmt"Added: {$t} - {cast[uint64](channel.addr)}"

proc getChannel*[Msg](hub: ChannelHub, t: typedesc[Msg]): var Channel[Msg] =
  ## Fetches the `Channel` associated with `Msg` from `hub`.
  let key: pointer = default(t).getTypeInfo()
  return cast[ptr Channel[Msg]](hub.channels[key])[]

proc debugSendLog[Msg](msg: Msg, hub: ChannelHub, success: bool) =
  let channelPtr = cast[uint64](hub.getChannel(Msg).addr)
  let msg = fmt"Thread '{getThreadId()}' => {msg.repr}"
  if success:
    debug fmt"send: {msg}"
  else:
    error fmt"failed to send: {msg}"

const SEND_PROC_NAME* = "sendMsgToChannel"
proc sendMsgToChannel*[Msg](hub: ChannelHub, msg: Msg): bool =
  ## Sends a message through the Channel associated with `Msg`.
  ## This is non-blocking.
  ## Returns `bool` stating if sending was successful.
  let success = hub.getChannel(Msg).trySend(msg)
  debugSendLog(msg, hub, success)
  return success

proc debugReadLog[Msg](msg: Msg, hub: ChannelHub) =
  let channelPtr = cast[uint64](hub.getChannel(Msg).addr)
  debug fmt"read: Thread '{getThreadId()}' <= {msg.repr}"

proc readMsg*[Msg](hub: ChannelHub, resp: typedesc[Msg]): Option[Msg] =
  ## Reads message from the Channel associated with `Msg`.
  ## This is non-blocking.
  var channel = hub.getChannel(Msg)
  
  let response: tuple[dataAvailable: bool, msg: Msg] = hub.getChannel(Msg).tryRecv()
  
  result = if response.dataAvailable:
      debugReadLog(response.msg, hub)
      some(response.msg)
    else:
      none(Msg)

