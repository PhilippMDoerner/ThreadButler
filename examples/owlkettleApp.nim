import appster
import appster/integration/owlkettleUtils
import owlkettle
import owlkettle/adw
import std/[sugar, options, logging, strformat]

addHandler(newConsoleLogger())

## Appster Type Setup

serverMessage:
  type S2CMessage = distinct string

type C2SMessage = object
  text: string

proc handleC2SMessage(msg: C2SMessage, hub: auto) {.serverRoute.} = 
  echo "On Server: Handling msg: ", msg.text
  discard hub.sendToClient(S2CMessage(fmt("Response to: {msg.text}")))

generate()

type ExampleServer = ServerData[ServerMessage, ClientMessage]
type Handler = proc(state: WidgetState, msg: ServerMessage)
viewable App:
  server: ExampleServer
  msg: ServerMessage
  inputText: string
  receivedMessages: seq[string]
  proc messageHandler(state: AppState, msg: ServerMessage) {.closure.}

proc handleMessage(state: AppState, msg: ServerMessage) = 
  case msg.kind:
  of S2CMessageKind:
      state.receivedMessages.add(msg.S2CMessageMsg.string)
  else:
    raise newException(ValueError, fmt"Unhandled kind: {msg.kind}")

proc send(app: AppState) =
  let msg = C2SMessage(text: app.inputText)
  discard app.server.sendMessage(msg)

method view(app: AppState): Widget =
  result = gui:
    Window:
      defaultSize = (500, 150)
      title = "Client Server Example"

      Box(orient = OrientY, margin = 12, spacing = 6):
        Button {.hAlign: AlignCenter, vAlign: AlignCenter.}:
          Label(text = "Click me")
          
          proc clicked() =
            let msg = C2SMessage(text: "Frontend message!")
            discard app.server.sendMessage(msg)
            
        Label(text = "Message sent by Backend: ")
        for msg in app.receivedMessages:
          Label(text = msg)

proc getServerStartupEvents(): seq[events.Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger()))
  result.add(loggerEvent)

  let helloWorldEvent = initEvent(() => debug "Server startin up!")
  result.add(helloWorldEvent)


## Main
proc main() =
  # Server

  var server: ServerData[ServerMessage, ClientMessage] = initServer(
    startupEvents = getServerStartupEvents(),
    shutdownEvents = @[],
    sleepInMs = 0
  )
  
  withServer(server):
    let listener = createListenerEvent(server, AppState)
    var appWidget = gui(App(
      server = server
    ))
    appWidget.messageHandler = owlkettle.Event[proc(state: AppState, msg: ServerMessage) {.closure.}](callback: handleMessage)

    adw.brew(
      appWidget,
      startupEvents = [listener]
    )

main()
