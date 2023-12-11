import std/[strformat, options]
import ./log

type ChannelHub*[SMsg, CMsg] = ref object
  serverChannel: Channel[SMsg] ## For server to receive messages to, ServerMessages get sent to server
  clientChannel: Channel[CMsg] ## For client to receive messages to, Clientmessages get sent to client

proc new*[SMsg, CMsg](t: typedesc[ChannelHub[SMsg, CMsg]]): ChannelHub[SMsg, CMsg] =
  result = ChannelHub[SMsg, CMsg]()
  result.serverChannel.open()
  result.clientChannel.open()
  
proc destroy*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]) =
  hub.serverChannel.close()
  hub.clientChannel.close()
  
proc debugLog[SMsg, CMsg](msg: SMsg | CMsg, success: bool) =
  debug when msg.typeOf() is CMsg:
      if success: 
        fmt"send client <= server: {msg.repr}"
      else: 
        fmt"Failed to send client <= server: {msg.repr}"
    else:
      if success: 
        fmt"send client => server: {msg.repr}"
      else: 
        fmt"Failed to send client => server: {msg.repr}"

const SEND_PROC_NAME* = "sendMsgToServer"
proc sendMsgToServer*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], msg: CMsg | SMsg): bool =
  let success = when msg.typeOf() is CMSg:
      hub.clientChannel.trySend(msg)
    elif msg.typeOf() is SMSg:
      hub.serverChannel.trySend(msg)
    else:
      error("Invalid")

  debugLog[SMsg, CMsg](msg, success)
  
  return success

proc readMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], resp: typedesc[CMsg]): Option[CMsg] =
  let response: tuple[dataAvailable: bool, msg: CMsg] = hub.clientChannel.tryRecv()
  
  result = if response.dataAvailable:
      debug fmt"read client <= server: {response.msg.repr}"
      some(response.msg)
    else:
      none(CMsg)

proc readMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg], resp: typedesc[SMsg]): Option[SMsg] =
  let response: tuple[dataAvailable: bool, msg: SMsg] = hub.serverChannel.tryRecv()

  result = if response.dataAvailable:
      debug fmt"read client => server: {response.msg.repr}"
      some(response.msg)
    else:
      none(SMsg)
    
proc hasServerMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]): bool =
  hub.serverChannel.peek() > 0
  
proc hasClientMsg*[SMsg, CMsg](hub: ChannelHub[SMsg, CMsg]): bool =
  hub.serverChannel.peek() > 0