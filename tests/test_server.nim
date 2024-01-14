import balls
import threadButler
import std/[sugar, options, os, sequtils, asyncdispatch]
const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct int
type Request = distinct int

var responses: seq[int] = @[]
var requests: seq[int] = @[]
var clientThreadStartupCounter: int = 0
var clientThreadShutdownCounter: int = 0
var serverThreadStartupCounter: int = 0
var serverThreadShutdownCounter: int = 0

threadServer(CLIENT_THREAD):
  properties:
    startUp = @[initEvent(() => clientThreadStartupCounter.inc)]
    shutDown = @[initEvent(() => clientThreadShutdownCounter.inc)]
  
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      responses.add(msg.int)

threadServer(SERVER_THREAD):
  properties:
    sleepMs = 50
    startUp = @[initEvent(() => serverThreadStartupCounter.inc)]
    shutDown = @[initEvent(() => serverThreadShutdownCounter.inc)]
  
  messageTypes:
    Request

  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      requests.add(msg.int)
      discard hub.sendMessage(Response(msg.int + 1))

prepareServers()

suite "Single Server Example":
  let hub = new(ChannelHub)
  
  block whenBlock: 
    discard "When SERVER_THREAD gets started and the main thread sends 10 messages with the numbers 0-9"
    hub.withServer(SERVER_THREAD):
      for i in 0..<10:
        while not hub.sendMessage(i.Request): discard
      
      while responses.len() < 10:
        var response: Option[ClientMessage] = hub.readMsg(ClientMessage)
        if response.isSome():
          routeMessage(response.get(), hub) 
  
  block thenBlock:
    discard "Then SERVER_THREAD should have variable of thread 'serverButlerThread', ran once and be shut down"
    check serverThreadStartupCounter == 1
    check serverThreadShutdownCounter == 1
    check serverButlerThread.running() == false
  
  block thenBlock:
    discard "Then CLIENT_THREAD should have variable of thread 'clientButlerThread' which should have never run"
    check clientThreadStartupCounter == 0
    check clientThreadShutdownCounter == 0
    check clientButlerThread.running() == false
  
  block thenBlock: 
    discard "Then SERVER_THREAD should fill requests with the numbers 0-9 and send the responses 1-10 to the main thread"
    check requests == (0..9).toSeq(), "Server did not receive Requests correctly"
    check responses == (1..10).toSeq(), "Client did not receive Responses correctly"

  block thenBlock:
    discard "Then channel for ClientMessage should be empty"
    check hub.getChannel(ClientMessage).peek() == 0
    check hub.getChannel(ServerMessage).peek() == 0
  
  hub.destroy()
