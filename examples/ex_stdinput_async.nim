import threadButler
import std/[sugar, logging, options, strformat, os, async, httpclient]

addHandler(newConsoleLogger())

const MAIN_THREAD = "main"
const SERVER_THREAD = "server"
type Response = distinct string
type Request = distinct string

threadServer(MAIN_THREAD):
  messageTypes:
    Response
  
  handlers:
    proc handleResponse(msg: Response, hub: ChannelHub) =
      debug "Do"
      debug "Finally received: ", msg.string
    
threadServer(SERVER_THREAD):
  properties:
    startUp = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) {.async.} = 
      let client = newAsyncHttpClient()
      let page = await client.getContent("http://www.google.com/search?q=" & msg.string)
      discard hub.sendMessage(Response(page))
    

prepareServers()

let hub = new(ChannelHub)

hub.withServer(SERVER_THREAD):
  when not defined(butlerDocs):
    while IS_RUNNING:
      echo "\nType in a message to send to the Backend for a google request!"
      # This is blocking, so this while-loop stalls here until the user hits enter. 
      # Thus the entire loop only runs once whenever the user hits enter. 
      # Thus it can only receive one message per enter press.
      let terminalInput = readLine(stdin)
      case terminalInput
      of "kill", "q", "quit":
        hub.sendKillMessage(ServerMessage)
        break
      else:
        let msg = terminalInput.Request
        discard hub.sendMessage(msg)
      
      ## Guarantees that the server has responded before we listen for user input again. 
      ## This is solely for neater logging when running the example.
      sleep(10) 
      
      let response: Option[MainMessage] = hub.readMsg(MainMessage)
      if response.isSome():
        routeMessage(response.get(), hub)

destroy(hub)