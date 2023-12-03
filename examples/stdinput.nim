import appster
import std/[sugar, logging]

type S2CMessage = object
type C2SMessage = object
  text: string

proc handleServerToClientMessage(msg: S2CMessage, hub: auto) {.clientRoute.} = 
  echo "On Client: Got Msg from Server: "
  
proc handleClientToServerMessage(msg: C2SMessage, hub: auto) {.serverRoute.} = 
  echo "On Server: Handling msg: ", msg.text

generate()

proc getStartupEvents(): seq[Event] =
  let loggerEvent = initEvent(() => addHandler(newConsoleLogger()))
  result.add(loggerEvent)

proc main() =
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

  echo "Type in a message to send to the Backend!"
  while true:
    let terminalInput = readLine(stdin) # This is blocking, so this Thread doesn't run through unnecessary while-loop iterations unlike the receiver thread
    let msg = C2SMessage(text: terminalInput)
    while not channels.sendToServer(msg):
      echo "Try again"
  joinThread(thread)

main()