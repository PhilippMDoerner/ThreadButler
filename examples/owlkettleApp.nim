import appster
import appster/integration/owlkettleUtils
import owlkettle
import owlkettle/adw
import std/[sugar, options, logging]

addHandler(newConsoleLogger())

## Appster Type Setup

serverMessage:
  type S2CMessage = object
    text: string

type C2SMessage = object
  text: string

proc handleC2SMessage(msg: C2SMessage, hub: auto) {.serverRoute.} = 
  echo "On Server: Handling msg: ", msg.text
  discard hub.sendToClient(S2CMessage(text: "Response!"))

generate()

type ExampleServer = ServerData[ServerMessage, ClientMessage]
## 

viewable App:
  server: ExampleServer
  msg: ServerMessage
  
  hooks:
    afterBuild:
      addServerListener(state, state.server)

method view(app: AppState): Widget =
  let backendMsg: Option[string] = case app.msg.kind:
    of S2CMessageKind: some(app.msg.S2CMessageMsg.text)
    else: none(string)
  
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
        if backendMsg.isSome():
          Label(text = backendMsg.get())

proc setupClient(server: ExampleServer) =
  let listener = createListenerEvent(server, AppState)
  adw.brew(
    gui(App(server = server)),
    startupEvents = [listener]
  )

proc getServerStartupEvents(): seq[events.Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger()))
  result.add(loggerEvent)

  let helloWorldEvent = initEvent(() => debug "Server startin up!")
  result.add(helloWorldEvent)


## Main
proc main() =
  # Server

  var data: ServerData[ServerMessage, ClientMessage] = initServer(
    startupEvents = getServerStartupEvents(),
    shutdownEvents = @[],
    sleepInMs = 0
  )
  
  withServer(data):
    setupClient(data)


main()
