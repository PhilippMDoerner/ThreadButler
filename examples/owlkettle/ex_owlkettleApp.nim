import threadButler
import threadButler/integration/owlkettleUtils
import ./server
import owlkettle
import owlkettle/adw
import std/[options, logging, strformat]

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

viewable App:
  server: ServerData[ServerMessage]
  inputText: string
  receivedMessages: seq[string]

proc sendAppMsg(app: AppState) =
  discard app.server.sendMessageToServer(app.inputText.Request)
  app.inputText = ""

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

proc handleResponse(msg: Response, hub: ChannelHub, state: AppState) {.registerRouteFor: CLIENT_THREAD_NAME.} =
  debug "On Client: Handling msg: ", msg.string
  state.receivedMessages.add(msg.string)

routingSetup("client", App)

## TODO: Make it so that closing the owlkettle client also kills the server.
## WithServer should send some kind of kill-message after the while-loop
## Provide remote thread killing facilities
## Each Variant and enum should automatically contain a "Kill<ThreadName>Kind"
## In the routing proc that triggers raising a ThreadKillError, which breaks the while-loop
## Generate a "killThreads(<ThreadNames>)" macro that generates the code to send a kill message to each thread specified.


## Main
proc main() =
  # Server
  var server = initOwlBackend[ServerMessage]()
  server.hub.addChannel(ServerMessage)
  server.hub.addChannel(ClientMessage)
  withServer(server):
    let listener = createListenerEvent(server, AppState, ClientMessage)
    var appWidget = gui(App(server = server))
    
    adw.brew(
      appWidget,
      startupEvents = [listener]
    )

main()
