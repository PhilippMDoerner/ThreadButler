import std/[options]
import pkg/owlkettle
import ./owlCodegen
import ../channelHub
import ../../threadButler

export generateOwlRouter

proc addServerListener*[OwlkettleApp: Viewable, SMsg, CMsg](
  app: OwlkettleApp, 
  data: Server[SMsg],
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

template createListenerEvent*(data: typed, stateType: typedesc, clientmsgType: typedesc): ApplicationEvent =
  ## Creates an Owlkettle.ApplicationEvent when starting up the application.
  ## This enables owlkettle to listen for messages received from the server
  ## and store them in the application's WidgetState.
  proc(state: WidgetState) =
    let state = stateType(state)
    addServerListener(state, data, clientmsgType)


template sendMessageToServer*(server: Server[typed], msg: auto): bool =
  server.hub.sendMessage(msg)