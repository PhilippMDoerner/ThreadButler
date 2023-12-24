import std/[options]
import pkg/owlkettle
import ./owlCodegen
import ../codegen
import ../channelHub
import ../../threadButler

export 
  owlCodegen.owlThreadServer,
  owlCodegen.prepareOwlServers

##[
  Utilities for easier integration with [Owlkettle](https://github.com/can-lehmann/owlkettle).
]##

proc addServerListener[State: WidgetState, CMsg](
  app: State, 
  hub: ChannelHub,  
  clientMsgType: typedesc[CMsg],
  sleepMs: int
) =  
  ## Adds a callback function to the GTK app that checks every 5 ms whether the 
  ## server sent a new message and routes it to the handler proc registered for that
  ## message kind. Triggers a UI update after executing the handler.

  mixin routeMessage
  proc listener(): bool =
    let msg = hub.readMsg(clientMsgType)
    if msg.isSome():
      routeMessage(msg.get(), hub, app)
      discard app.redraw()
    
    const KEEP_LISTENER_ACTIVE = true
    return KEEP_LISTENER_ACTIVE

  discard addGlobalTimeout(sleepMs, listener)

proc createListenerEvent*[State: WidgetState](
  hub: ChannelHub, 
  stateType: typedesc[State], 
  threadName: static string,
  sleepMs: int = 5
): ApplicationEvent =
  ## Creates an Owlkettle.ApplicationEvent that registers a global timeout with owlkettle.
  ## Owlkettle executes these events when the owlkettle application starts.
  ## 
  ## The global timeout checks for and routes new messages every `sleepMs` for the 
  ## `threadName` threadServer on `hub`. 
  ## 
  ## The handler-proc for that message type then gets executed with the message, `hub` and 
  ## owlkettle's root widget's WidgetState `stateType`.
  proc(state: WidgetState) =
    let state = stateType(state)
    addServerListener[State, threadName.toVariantType()](state, hub, threadName.toVariantType(), sleepMs)