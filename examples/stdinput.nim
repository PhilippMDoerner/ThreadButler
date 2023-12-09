import appster
import std/[sugar, logging]

type S2CMessage = distinct string
type C2SMessage = distinct string
type KillMessage = object

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

proc handleClientToServerMessage(msg: C2SMessage, hub: auto) {.route: "server".} = 
  echo "On Server: Handling msg: ", msg.string

proc triggerShutdown(msg: KillMessage, hub: auto) {.route: "server".} =
  shutdownServer()

generate("server")
generate("client")

proc getStartupEvents(): seq[Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] ")))
  result.add(loggerEvent)

  let helloWorldEvent = initEvent(() => debug "Server startin up!")
  result.add(helloWorldEvent)
  
proc getShutdownEvents(): seq[Event] =
  let byebyeWorldEvent = initEvent(() => debug "Server shutting down!")
  result.add(byebyeWorldEvent)

proc main() =
  var channels = new(ChannelHub[ServerMessage, ClientMessage])
  let sleepMs = 10
  var data: ServerData[ServerMessage, ClientMessage] = ServerData[ServerMessage, ClientMessage](
    hub: channels,
    sleepMs: sleepMs,
    startUp: getStartupEvents(),
    shutDown: getShutdownEvents()
  )
  
  let thread: Thread[
    ServerData[ServerMessage, ClientMessage]
  ] = data.runServer()

  echo "Type in a message to send to the Backend!"
  while true:
    let terminalInput = readLine(stdin) # This is blocking, so this Thread doesn't run through unnecessary while-loop iterations unlike the receiver thread
    if terminalInput == "kill":
      discard channels.sendMessage(KillMessage())
      break
    
    else:
      let msg = terminalInput.C2SMessage
      discard channels.sendMessage(msg)

  joinThread(thread)

main()