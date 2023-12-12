import threadButler
import std/[sugar, logging, options, strformat, os]

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

const CLIENT_THREAD_NAME = "client"
const SERVER_THREAD_NAME = "server"

registerTypeFor(CLIENT_THREAD_NAME):
  type Response = distinct string

registerTypeFor(SERVER_THREAD_NAME):
  type Request = distinct string
  type KillMessage = object

generateTypes()

registerRouteFor(SERVER_THREAD_NAME):
  proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
    debug "On Server: ", msg.string
    discard hub.sendMessage(Response("Handled: " & msg.string))

proc triggerShutdown(msg: KillMessage, hub: ChannelHub) {.registerRouteFor: SERVER_THREAD_NAME.} =
  shutdownServer()

proc handleResponseOnClient(msg: Response, hub: ChannelHub) {.registerRouteFor: CLIENT_THREAD_NAME.} =
  debug "On Client: ", msg.string

generateRouter()

proc main() =
  var hub = new(ChannelHub)
  let sleepMs = 10
  let data: ServerData[ServerMessage] = ServerData[ServerMessage](
    hub: hub,
    msgType: default(ServerMessage),
    sleepMs: sleepMs,
    startUp: @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ],
    shutDown: @[initEvent(() => debug "Server shutting down!")]
  )
  
  let thread: Thread[ServerData[ServerMessage]] = data.runServer()

  while true:
    echo "\nType in a message to send to the Backend!"
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    if terminalInput == "kill":
      discard hub.sendMessage(KillMessage())
      break
    
    elif terminalInput.len() > 0:
      let msg = terminalInput.Request
      discard hub.sendMessage(msg)
    
    ## Guarantees that we'll have the response from server before we listen for user input again. 
    ## This is solely for better logging, do not use in actual code.
    sleep(100) 
    
    let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), hub)

  joinThread(thread)
  destroy(hub)

main()