import threadButler
import threadButler/log
import std/[sugar, options, os]
import taskpools
import chronicles

const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct string
type Request = distinct string

proc runLate(hub: ChannelHub) {.gcsafe, raises: [].}

threadServer(CLIENT_THREAD):
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      debug "On Client: ", msg = msg.string

var threadPool: TaskPool

threadServer(SERVER_THREAD):
  properties:
    taskPoolSize = 2
    startUp = @[
      initCreateTaskpoolEvent(size = 2, threadPool),
      initEvent(() => debug "Server startin up!"),
    ]
    shutDown = @[
      initDestroyTaskpoolEvent(threadPool),
      initEvent(() => debug "Server shutting down!")
    ]

  messageTypes:
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      debug "On Server: ", msg = msg.string
      threadPool.spawn hub.runLate()
      discard hub.sendMessage(Response("Handled: " & msg.string))

prepareServers()

proc runClientLoop(hub: ChannelHub) =
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
    sleep(100) 
    
    let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), hub)

proc runLate(hub: ChannelHub) =
  debug "Start"
  sleep(1000)
  let msg = "Run with delay: " & $getThreadId()
  try:
    discard hub.sendMessage(msg.Response)
  except ChannelHubError as e:
    error "Failed to send message. ", error = e.repr

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD):
    runClientLoop(hub)
  
  destroy(hub)

main()