import balls
import threadButler
import std/[sugar, options, os, atomics, sequtils, asyncdispatch]
const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct int
type Request = distinct int

var responses: Atomic[int]
var requests: Atomic[int]
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
      responses.atomicInc

threadServer(SERVER_THREAD):
  properties:
    sleepMs = 50
    startUp = @[initEvent(() => serverThreadStartupCounter.inc)]
    shutDown = @[initEvent(() => serverThreadShutdownCounter.inc)]
  
  messageTypes:
    Request

  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) {.async.} = 
      requests.atomicInc
      await sleepAsync(10)
      discard hub.sendMessage(Response(msg.int + 1))

prepareServers()

const MESSAGE_COUNT = 10

suite "Single Server Example":
  let hub = new(ChannelHub)
  
  block whenBlock: 
    discard "When SERVER_THREAD gets started and the main thread sends 10 messages with the numbers 0-9"
    hub.withServer(SERVER_THREAD):
      for i in 0..<MESSAGE_COUNT:
        while not hub.sendMessage(i.Request): discard
      
      while responses.load() != MESSAGE_COUNT:
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
    check requests.load() == MESSAGE_COUNT, "Server did not receive Requests correctly"
    check responses.load() == MESSAGE_COUNT, "Client did not receive Responses correctly"

  block thenBlock:
    discard "Then channel for ClientMessage should be empty"
    check hub.getChannel(ClientMessage).peek() == 0
    check hub.getChannel(ServerMessage).peek() == 0
  
  hub.destroy()
