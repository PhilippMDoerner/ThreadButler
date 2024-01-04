import threadButler
import std/[sugar, logging, options, os]

const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct string
type Request = ref object
  text: ref string

threadServer(CLIENT_THREAD):
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      debug "On Client: ", msg = msg.string
    
threadServer(SERVER_THREAD):
  properties:
    startUp = @[
      initEvent(() => debug "Server startin up!")
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      debug "On Server: ", msgPtr = cast[uint64](msg)

      discard hub.sendMessage(Response("Handled: " & msg.text[]))

prepareServers()

proc runClientLoop(hub: ChannelHub) =
  while IS_RUNNING:
    echo "\nType in a message to send to the Backend!"
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    if terminalInput == "kill":
      hub.sendKillMessage(ServerMessage)
      hub.clearServerChannel(ClientMessage)
      break
    
    elif terminalInput.len() > 0:
      let str = new(string)
      str[] = terminalInput
      let msg = Request(text: str)
      debug "On Client: ", msgPtr = cast[uint64](msg)
      discard hub.sendMessage(msg)
      sleep(3000)
      debug "Unsafe access: ",  msgPtr = cast[uint64](msg), msgContent = msg[].repr
    ## Guarantees that we'll have the response from server before we listen for user input again. 
    ## This is solely for better logging, do not use in actual code.
    sleep(100)
    
    let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), hub)

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD):
    runClientLoop(hub)
  
  destroy(hub)

main()