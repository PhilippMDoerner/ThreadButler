import threadButler
import std/[sugar, logging, options, asyncdispatch, strformat]

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct string
type Request = distinct string

threadServer(CLIENT_THREAD):
  properties:
    sleepMs: 50
    startUp = @[]
    shutDown = @[]
    
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) {.async, gcsafe.} =
      debug "On Client: ", msg.string
      await sleepAsync(500)
      debug "Post sleep"
      discard hub.sendMessage(Request("Continue: " & msg.string))

threadServer(SERVER_THREAD):
  properties:
    sleepMs = 100
    startUp = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Request

  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      debug "On Server: ", msg.string
      discard hub.sendMessage(Response("Handled: " & msg.string))

prepareServers()

proc runClientLoop(hub: ChannelHub) =
  discard sleeper()
  while IS_RUNNING:
    echo "\nType in a message to send to the Backend!"
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    if terminalInput == "kill":
      hub.sendKillMessage(ServerMessage)
      break
    
    elif terminalInput.len() > 0:
      let msg = terminalInput.Request
      discard hub.sendMessage(msg)
    
    ## Guarantees that we'll have the response from server before we listen for user input again. 
    ## This is solely for better logging, do not use in actual code.
    poll(100) 
    
    let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), hub)

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD):
    runClientLoop(hub)
  
  hub.destroy()

main()