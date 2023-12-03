import owlkettle
import owlkettle/bindings/gtk
import ../communication
import appster
import std/[strformat, options, re, strutils]
  
proc addServerListener*[App, SMsg, CMsg](app: App, data: ServerData[SMsg, CMsg], sleepMs: int = 5) =
  mixin clientRouteMessage
  for typ in SMsg.kind:
    echo "Enum type: ", typ
  
  ## Adds a callback function to the GTK app that checks every 5 ms whether the 
  ## server sent a new message. Triggers a UI update if that is the case.
  proc listener(): bool =
    let msg = data.hub.readServerMsg()
    if msg.isSome():
      app.msg = msg.get()
      discard app.redraw()
    
    const KEEP_LISTENER_ACTIVE = true
    return KEEP_LISTENER_ACTIVE

  discard addGlobalTimeout(sleepMs, listener)

proc sendMessage*[SMsg, CMsg](serverData: ServerData[SMsg, CMsg], msg: auto): bool =
  mixin sendToServer
  serverData.hub.sendToServer(msg)