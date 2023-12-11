import threadButler
import std/[sugar, logging, options, strformat]

const CLIENT_THREAD_NAME = "client"
const SERVER_THREAD_NAME = "server"

registerTypeFor(CLIENT_THREAD_NAME):
  type Response = distinct string

registerTypeFor(SERVER_THREAD_NAME):
  type Request = distinct string
  type KillMessage = object

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

proc handleRequestOnServer(msg: Request, hub: ChannelHub) {.registerRouteFor: SERVER_THREAD_NAME.} = 
  discard hub.sendMessage(Response("Handled: " & msg.string))

proc triggerShutdown(msg: KillMessage, hub: ChannelHub) {.registerRouteFor: SERVER_THREAD_NAME.} =
  shutdownServer()

proc handleResponseOnClient(msg: Response, hub: ChannelHub) {.registerRouteFor: CLIENT_THREAD_NAME.} =
  debug "On Client: ", msg.string

generate(SERVER_THREAD_NAME)
generate(CLIENT_THREAD_NAME)

proc main() =
  var channels = new(ChannelHub[ServerMessage, ClientMessage])
  let sleepMs = 10
  var data: ServerData[ServerMessage, ClientMessage] = ServerData[ServerMessage, ClientMessage](
    hub: channels,
    sleepMs: sleepMs,
    startUp: @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ],
    shutDown: @[initEvent(() => debug "Server shutting down!")]
  )
  
  let thread: Thread[ServerData[ServerMessage, ClientMessage]] = data.runServer()

  echo "Type in a message to send to the Backend!"
  while true:
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    if terminalInput == "kill":
      discard channels.sendMessage(KillMessage())
      break
    
    elif terminalInput.len() > 0:
      let msg = terminalInput.Request
      discard channels.sendMessage(msg)
    
    let response: Option[ClientMessage] = channels.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), channels)

  joinThread(thread)

main()