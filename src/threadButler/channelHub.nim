import std/[strformat, options, tables]
import ./log

##[
Defines utilities for interacting with a ChannelHub.
Further utilities may be generated by `codegen`.

A ChannelHub is a table of **all** Channels to *all* thread-servers in an application.
It contains one Channel per registered Thread through which one specific "Message"-object variant can be sent.
The channel for a given Message-object-variant is stored with (and can thus be retrieved with) data inferred from the object-variant.
]##

type ChannelHubError* = object of KeyError

type ChannelHub* = object
  channels*: Table[pointer, pointer]

template generateGetChannelProc(typ: untyped) =
  proc getChannel*[Msg](hub: ChannelHub, t: typedesc[Msg]): var typ[Msg] {.raises: [ChannelHubError].} =
    ## Fetches the `Channel` associated with `Msg` from `hub`.
    let key: pointer = default(t).getTypeInfo()
    var channelPtr: pointer = nil
    try:
      channelPtr = hub.channels[key]
    except KeyError as e:
      const msgName = $Msg
      raise (ref ChannelHubError)(
        msg: "There is no Channel for the message type '" & msgName & "'.",
        parent: e
      )
    
    return cast[ptr typ[Msg]](channelPtr)[] 

# CHANNEL SPECIFICS
when defined(butlerThreading):
  import pkg/threading/channels
  import std/isolation
  export channels

  generateGetChannelProc(Chan)

  proc createChannel[Msg](capacity: int): ptr Chan[Msg] =
    result = createShared(Chan[Msg])
    result[] = newChan[Msg](capacity)
  
  proc destroyChannel*[Msg](chan: Chan[Msg]) =
    `=destroy`(chan)

elif defined(butlerLoony):
  import pkg/loony
  export loony

  generateGetChannelProc(LoonyQueue)

  proc createChannel[Msg](capacity: int): ptr LoonyQueue[Msg] =
    result = createShared(LoonyQueue[Msg])
    result[] = newLoonyQueue[Msg]()
          
  proc tryRecv[T](c: LoonyQueue[T]): tuple[dataAvailable: bool, msg: T] =
    let msg = c.pop()
    result.msg = msg
    result.dataAvailable = not msg.isNil()

  proc trySend[T](c: LoonyQueue[T]; msg: sink T): bool =
    c.push(msg)
    return true
  
  proc destroyChannel*[Msg](chan: LoonyQueue[Msg]) =
    `=destroy`(chan)
    discard

else:
  generateGetChannelProc(Channel)

  proc createChannel[Msg](capacity: int): ptr Channel[Msg] =
    result = createShared(Channel[Msg])
    result[] = Channel[Msg]()
    result[].open()

  proc destroyChannel*[Msg](chan: var Channel[Msg]) =
    chan.close()
    `=destroy`(chan)

const SEND_PROC_NAME* = "sendMsgToChannel"
proc sendMsgToChannel*[Msg](hub: ChannelHub, msg: sink Msg): bool {.raises: [ChannelHubError].} =
  ## Sends a message through the Channel associated with `Msg`.
  ## This is non-blocking.
  ## Returns `bool` stating if sending was successful.
  debug "send: Thread => Channel", msgTyp = $Msg, msg = msg.kind
    
  try:
    when defined(butlerThreading):
      result = hub.getChannel(Msg).trySend(unsafeIsolate(move(msg))) 
    else:
      result = hub.getChannel(Msg).trySend(move(msg)) 
    
    if not result:
      debug "Failed to send message"

  except Exception as e:
    raise (ref ChannelHubError)(
      msg: "Error while sending message",
      parent: e
    )
    
proc readMsg*[Msg](hub: ChannelHub, resp: typedesc[Msg]): Option[Msg] =
  ## Reads message from the Channel associated with `Msg`.
  ## This is non-blocking.
  let response: tuple[dataAvailable: bool, msg: Msg] = 
    when defined(butlerThreading):
      var msg: Msg
      let hasMsg = hub.getChannel(Msg).tryRecv(msg)
      (hasMsg, msg)
    else:
      hub.getChannel(Msg).tryRecv()

  result = if response.dataAvailable:
      debug "read: Thread <= Channel", msgTyp = $Msg, msg = response.msg.kind
      some(response.msg)
    else:
      none(Msg)

proc addChannel*[Msg](hub: var ChannelHub, t: typedesc[Msg], capacity: int) =
  ## Instantiates and opens a `Channel` to `hub` specifically for type `Msg`.
  ## This associates it with `Msg`. 
  let key: pointer = default(Msg).getTypeInfo()
  let channel: pointer = createChannel[Msg](capacity) 
  hub.channels[key] = channel
  
  let keyInt = cast[uint64](key)
  let channelInt = cast[uint64](channel)
  let typ = $Msg
  notice "Added Channel", typ, keyInt, channelInt 