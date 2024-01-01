import threadButler
import threadButler/integration/owlButler
import std/[sugar]
import chronicles

const CLIENT_THREAD* = "client"
const SERVER_THREAD* = "server"
type Response* = distinct string
type Request* = distinct string

threadServer(SERVER_THREAD):
  properties:
    startUp = @[
      initEvent(() => debug "Server startin up!")
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Request

  handlers:
    proc handleRequest*(msg: Request, hub: ChannelHub) = 
      let resp = Response(fmt("Response to: {msg.string}"))
      discard hub.sendMessage(resp)

owlThreadServer(CLIENT_THREAD):
  messageTypes:
    Response
  
  handlers:
    proc handleResponse(msg: Response, hub: ChannelHub, state: AppState) =
      debug "On Client: Handling msg: ", msg = msg.string
      state.receivedMessages.add(msg.string)
