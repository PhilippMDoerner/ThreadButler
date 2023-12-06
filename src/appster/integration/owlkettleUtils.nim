import pkg/owlkettle
import pkg/owlkettle/bindings/gtk
import ../communication
import ../../appster
import std/[strformat, options, re, strutils]
  
proc addServerListener*[OwlkettleApp: Viewable, SMsg, CMsg](
  app: OwlkettleApp, 
  data: ServerData[SMsg, CMsg]
) =  
  ## Adds a callback function to the GTK app that checks every 5 ms whether the 
  ## server sent a new message. Triggers a UI update if that is the case.
  proc listener(): bool =
    let msg = data.hub.readServerMsg()
    if msg.isSome():
      app.msg = msg.get()
      discard app.redraw()
    
    const KEEP_LISTENER_ACTIVE = true
    return KEEP_LISTENER_ACTIVE

  discard addGlobalTimeout(data.sleepMs, listener)

proc sendMessage*[SMsg, CMsg](serverData: ServerData[SMsg, CMsg], msg: auto): bool =
  mixin sendToServer
  serverData.hub.sendToServer(msg)

template createListenerEvent*(data: typed, stateType: typedesc): ApplicationEvent =
  ## Creates an Owlkettle.ApplicationEvent when starting up the application.
  ## This enables owlkettle to listen for messages received from the server
  ## and store them in the application's WidgetState.
  proc(state: WidgetState) =
    let state = stateType(state)
    addServerListener(state, data)

template initServer*(
  shutdownEvents: seq[events.Event] = @[],
  startupEvents: seq[events.Event] = @[],
  sleepInMs: int = 0
): untyped =
  ServerData[ServerMessage, ClientMessage](
    hub: new(ChannelHub[ServerMessage, ClientMessage]),
    sleepMs: sleepInMs,
    startUp: startupEvents,
    shutDown: shutdownEvents
  )

template withServer*(
  data: var ServerData[typed, typed],
  body: untyped
) =
  let thread: Thread[ServerData[typed, typed]] = runServer(data)

  body
  
  joinThread(thread)
  data.hub.destroy()