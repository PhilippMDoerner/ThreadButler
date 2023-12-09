import appster
import appster/integration/owlkettleUtils
import owlkettle
import owlkettle/adw
import std/[sugar, options, logging, strformat]

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

# ## Appster Type Setup

type S2CMessage = distinct string
type C2SMessage = distinct string

proc handleC2SMessage(msg: C2SMessage, hub: auto) {.route: "server".} = 
  echo "On Server: Handling msg: ", msg.string
  discard hub.sendMessage(S2CMessage(fmt("Response to: {msg.string}")))

proc handleS2CMessage(msg: S2CMessage, hub: auto, state: WidgetState) {.route: "client".}

generate("server")
owlGenerate("client", "App")

viewable App:
  server: ServerData[ServerMessage, ClientMessage]
  inputText: string
  receivedMessages: seq[string]

method view(app: AppState): Widget =
  result = gui:
    Window:
      defaultSize = (500, 150)
      title = "Client Server Example"

      Box(orient = OrientY, margin = 12, spacing = 6):
        Button {.hAlign: AlignCenter, vAlign: AlignCenter.}:
          Label(text = "Click me")
          
          proc clicked() =
            let msg = "Frontend message!".C2SMessage
            discard app.server.sendMessageToServer(msg)
            
        Label(text = "Message sent by Backend: ")
        for msg in app.receivedMessages:
          Label(text = msg)

proc handleS2CMessage(msg: S2CMessage, hub: auto, state: WidgetState) =
  echo "On Client: Handling msg: ", msg.string
  let state = state.AppState
  state.receivedMessages.add(msg.string)

proc getServerStartupEvents(): seq[events.Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] ")))
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
    var appWidget = gui(App(server = server))
    
    adw.brew(
      appWidget,
      startupEvents = [listener]
    )

main()
