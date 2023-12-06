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

proc createListenerEvent*[T: WidgetState, SMsg, CMsg](data: ServerData[SMsg, CMsg]): ApplicationEvent =
  result = proc(state: WidgetState) =
    let state = T(state)
    addServerListener(state, data)
