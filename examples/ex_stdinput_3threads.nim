import threadButler
import std/[sugar, options, strutils, os]
import chronicles 

const CLIENT_THREAD = "client"
const SERVER1_THREAD = "mainServer"
const SERVER2_THREAD = "offloadServer"
type Response = distinct string
type OffloadRequest = distinct string
type Request = distinct string

threadServer(CLIENT_THREAD):
  messageTypes:
    Response

  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      debug "On Client: ", msg = msg.string

threadServer(SERVER1_THREAD):
  properties:
    startUp = @[
      initEvent(() => debug "Server startin up!")
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      debug "On Server: ", msg = msg.string
      discard hub.sendMessage(OffloadRequest("Forwarding: " & msg.string))
      discard hub.sendMessage(Response("Handled: " & msg.string))

threadServer(SERVER2_THREAD):
  properties:
    startUp = @[
      initEvent(() => debug "Server startin up!")
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]
    
  messageTypes:
    OffloadRequest
  
  handlers:
    proc handleOffloadRequest(msg: OffloadRequest, hub: ChannelHub) =
      debug "Work offloaded to OffloadSerevr"

prepareServers()

proc runClientLoop(hub: ChannelHub) =
  while IS_RUNNING:
    echo "\nType in a message to send to the Backend!"
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    if terminalInput == "kill":
      hub.sendKillMessage(MainServerMessage)
      hub.clearServerChannel(ClientMessage)
      break
    
    elif terminalInput.len() > 0:
      if terminalInput.startsWith("main"):
        let msg = terminalInput.Request
        discard hub.sendMessage(msg)
      else:
        let msg = terminalInput.OffloadRequest
        discard hub.sendMessage(msg)
    
    ## Guarantees that we'll have the response from server before we listen for user input again. 
    ## This is solely for better logging, do not use in actual code.
    sleep(100) 
    
    let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), hub)

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER1_THREAD):
    hub.withServer(SERVER2_THREAD):
      runClientLoop(hub)
  
  destroy(hub)

main()