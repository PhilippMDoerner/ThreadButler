import threadButler
import std/[logging, strformat, sugar]

const CLIENT_THREAD_NAME* = "client"
const SERVER_THREAD_NAME* = "server"

registerTypeFor(CLIENT_THREAD_NAME):
  type Response* = distinct string
  
registerTypeFor(SERVER_THREAD_NAME):
  type Request* = distinct string

generateSetupCode()

proc handleRequest*(msg: Request, hub: ChannelHub) {.registerRouteFor: SERVER_THREAD_NAME.} = 
  let resp = Response(fmt("Response to: {msg.string}"))
  discard hub.sendMessage(resp)

proc newSingleServer*[Msg](): Server[Msg] =  
  result = Server[Msg](
    hub: new(ChannelHub),
    startUp: @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ],
    shutDown: @[initEvent(() => debug "Server shutting down!")],
    sleepMs: 0
  ) 