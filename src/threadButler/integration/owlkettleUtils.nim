import std/[options]
import pkg/owlkettle
import ./owlCodegen
import ../channelHub
import ../../threadButler

export owlSetup, routingSetup

proc addServerListener*[OwlkettleApp: Viewable, SMsg, CMsg](
  app: OwlkettleApp, 
  data: ServerData[SMsg],
  clientMsgType: typedesc[CMsg]
) =  
  ## Adds a callback function to the GTK app that checks every 5 ms whether the 
  ## server sent a new message. Triggers a UI update if that is the case.
  mixin routeMessage
  let hub: ChannelHub = data.hub
  proc listener(): bool =
    let msg = data.hub.readMsg(clientMsgType)
    if msg.isSome():
      routeMessage(msg.get(), hub, app)
      discard app.redraw()
    
    const KEEP_LISTENER_ACTIVE = true
    return KEEP_LISTENER_ACTIVE

  discard addGlobalTimeout(data.sleepMs, listener)

# proc addClientSender*[SMsg, CMsg](data: ServerData[SMsg, CMsg]) =
#   proc sender(): bool =
    

template createListenerEvent*(data: typed, stateType: typedesc, clientmsgType: typedesc): ApplicationEvent =
  ## Creates an Owlkettle.ApplicationEvent when starting up the application.
  ## This enables owlkettle to listen for messages received from the server
  ## and store them in the application's WidgetState.
  proc(state: WidgetState) =
    let state = stateType(state)
    addServerListener(state, data, clientmsgType)

proc initServer*[Msg](
  shutdownEvents: seq[events.Event] = @[],
  startupEvents: seq[events.Event] = @[],
  sleepInMs: int = 0
): ServerData[Msg] =
  ServerData[Msg](
    hub: new(ChannelHub),
    sleepMs: sleepInMs,
    startUp: startupEvents,
    shutDown: shutdownEvents
  )

template withServer*[Msg](
  data: ServerData[Msg],
  body: untyped
) =
  mixin sendKillMessage
  let thread: Thread[ServerData[Msg]] = runServer(data)

  body
  
  data.hub.sendKillMessage(Msg.type)
  joinThread(thread)
  data.hub.destroy()
  
template sendMessageToServer*(server: ServerData[typed], msg: auto): bool =
  server.hub.sendMessage(msg)