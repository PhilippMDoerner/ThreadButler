# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import balls

import threadButler
import std/[sugar, options, os]

const CLIENT_THREAD = "client"
const SERVER_THREAD = "server"
type Response = distinct string
type Request = distinct string

var responses: seq[string] = @[]
var requests: seq[string] = @[]

threadServer(CLIENT_THREAD):
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      responses.add(msg.string)

threadServer(SERVER_THREAD):
  messageTypes:
    Request

  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      requests.add(msg.string)
      discard hub.sendMessage(Response("Ping"))

prepareServers()

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD):
    let success = hub.sendMessage("TestMessage".Request)
    doAssert success == true
    
    var response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    while response.isNone():
      response = hub.readMsg(ClientMessage)
    routeMessage(response.get(), hub) 

  hub.destroy()
  
  doAssert requests == @["TestMessage"]
  doAssert responses == @["Ping"]

main()