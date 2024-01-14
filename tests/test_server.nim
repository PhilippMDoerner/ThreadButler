import balls
import threadButler
import std/[sugar, options, os, sequtils, asyncdispatch]
const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct int
type Request = distinct int

var responses: seq[int] = @[]
var requests: seq[int] = @[]

threadServer(CLIENT_THREAD):
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      responses.add(msg.int)

threadServer(SERVER_THREAD):
  properties:
    sleepMs = 50

  messageTypes:
    Request

  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      requests.add(msg.int)
      discard hub.sendMessage(Response(msg.int + 1))

prepareServers()

suite "Single Server Example":
  let hub = new(ChannelHub)
  
  block simpleServer: 
    hub.withServer(SERVER_THREAD):
      for i in 0..<10:
        while not hub.sendMessage(i.Request): discard
      
      while responses.len() < 10:
        var response: Option[ClientMessage] = hub.readMsg(ClientMessage)
        if response.isSome():
          routeMessage(response.get(), hub) 

    check requests == (0..9).toSeq(), "Server did not receive Requests correctly"
    check responses == (1..10).toSeq(), "Client did not receive Responses correctly"
  
  hub.destroy()
