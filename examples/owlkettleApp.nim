import appster
import appster/integration/owlkettleUtils
import owlkettle
import owlkettle/adw
import std/[sugar, options, logging]

addHandler(newConsoleLogger())

type S2CMessage = object
  text: string

type C2SMessage = object
  text: string

proc handleS2CMessage(msg: S2CMessage, hub: auto) {.clientRoute.} = 
  echo "On Client: Got Msg from Server: "
  
proc handleC2SMessage(msg: C2SMessage, hub: auto) {.serverRoute.} = 
  echo "On Server: Handling msg: ", msg.text
  discard hub.sendToClient(S2CMessage(text: "Response!"))

generate()

viewable App:
  server: ServerData[ServerMessage, ClientMessage]
  msg: ServerMessage
  
  hooks:
    afterBuild:
      addServerListener(state, state.server)

method view(app: AppState): Widget =
  let backendMsg: Option[string] = case app.msg.kind:
    of handleS2CMessageKind: some(app.msg.handleS2CMessageMsg.text)
    else: none(string)
  
  result = gui:
    Window:
      defaultSize = (500, 150)
      title = "Client Server Example"
      
      Box:
        orient = OrientY
        margin = 12
        spacing = 6
        
        Button {.hAlign: AlignCenter, vAlign: AlignCenter.}:
          Label(text = "Click me")
          
          proc clicked() =
            let msg = C2SMessage(text: "Frontend message!")
            discard app.server.sendMessage(msg)
            

        Label(text = "Message sent by Backend: ")
        if backendMsg.isSome():
          Label(text = backendMsg.get())

proc setupClient[ServerMessage, ClientMessage](server: ServerData[ServerMessage, ClientMessage]) =
  adw.brew(gui(App(server = server)))

proc getStartupEvents(): seq[events.Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger()))
  result.add(loggerEvent)

  let helloWorldEvent = initEvent(() => debug "Server startin up!")
  result.add(helloWorldEvent)

## Main
proc main() =
  # Server
  var channels = new(ChannelHub[ServerMessage, ClientMessage])
  let sleepMs = 0
  var data: ServerData[ServerMessage, ClientMessage] = ServerData[ServerMessage, ClientMessage](
    hub: channels,
    sleepMs: sleepMs,
    startUp: getStartupEvents(),
    shutDown: @[]
  )
  let thread: Thread[
    ServerData[ServerMessage, ClientMessage]
  ] = data.runServer()
  
  setupClient(data)
  joinThread(thread)
  
  data.hub.destroy()

main()


