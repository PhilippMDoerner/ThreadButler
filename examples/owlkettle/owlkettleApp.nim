import appster
import appster/integration/owlkettleUtils
import ./server
import owlkettle
import owlkettle/adw
import std/[options, logging, strformat]

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

# ## Appster Type Setup
proc handleResponse(msg: Response, hub: ChannelHub, state: WidgetState) {.route: "client".}

owlGenerateAll("client")

proc sendAppMsg(app: auto) =
  discard app.server.sendMessageToServer(app.inputText.Request)
  app.inputText = ""

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
        Box(orient = OrientX) {.expand: false.}:
          Entry(placeholder = "Send message to server!", text = app.inputText):
            proc changed(newText: string) =
              app.inputText = newText
            proc activate() =
              app.sendAppMsg()
              
          Button {.expand: false}:
            style = [ButtonSuggested]
            proc clicked() =
              app.sendAppMsg()
              
            Box(orient = OrientX, spacing = 6):
              Label(text = "send") {.vAlign: AlignFill.}
              Icon(name = "mail-unread-symbolic") {.vAlign: AlignFill, hAlign: AlignCenter, expand: false.}
              
        Separator(margin = Margin(top: 24, bottom: 24, left: 0, right: 0))
        
        Label(text = "Responses from server:", margin = Margin(bottom: 12))
        for msg in app.receivedMessages:
          Label(text = msg) {.hAlign: AlignStart.}

proc handleResponse(msg: Response, hub: ChannelHub, state: WidgetState) =
  echo "On Client: Handling msg: ", msg.string
  let state = state.AppState
  state.receivedMessages.add(msg.string)


## Main
proc main() =
  # Server
  var server = initServerData[ServerMessage, ClientMessage]()
  
  withServer(server):
    let listener = createListenerEvent(server, AppState)
    var appWidget = gui(App(server = server))
    
    adw.brew(
      appWidget,
      startupEvents = [listener]
    )

main()
