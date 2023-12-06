import appster
import std/[sugar, logging]

serverMessage:
  type S2CMessage = object

type C2SMessage = object
  text: string

type KillMessage = object
  
proc handleClientToServerMessage(msg: C2SMessage, hub: auto) {.serverRoute.} = 
  echo "On Server: Handling msg: ", msg.text

proc triggerShutdown(msg: KillMessage, hub: auto) {.serverRoute.} =
  shutdownServer()

generate()

proc getStartupEvents(): seq[Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger()))
  result.add(loggerEvent)

  let helloWorldEvent = initEvent(() => debug "Server startin up!")
  result.add(helloWorldEvent)
  
proc getShutdownEvents(): seq[Event] =
  let byebyeWorldEvent = initEvent(() => debug "Server shutting down!")
  result.add(byebyeWorldEvent)

proc main() =
  var channels = new(ChannelHub[ServerMessage, ClientMessage])
  let sleepMs = 0
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
      discard channels.sendToServer(KillMessage())
      break
    
    else:
      let msg = C2SMessage(text: terminalInput)
      discard channels.sendToServer(msg)

  joinThread(thread)

main()