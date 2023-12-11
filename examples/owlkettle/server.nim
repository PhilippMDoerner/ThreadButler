import threadButler
import threadButler/integration/owlkettleUtils
import std/[logging, strformat, sugar]

const CLIENT_THREAD_NAME* = "client"
const SERVER_THREAD_NAME* = "server"

registerTypeFor(CLIENT_THREAD_NAME):
  type Response* = distinct string
  
registerTypeFor(SERVER_THREAD_NAME):
  type Request* = distinct string

proc handleRequest*(msg: Request, hub: ChannelHub) {.registerRouteFor: SERVER_THREAD_NAME.} = 
  let resp = Response(fmt("Response to: {msg.string}"))
  discard hub.sendMessage(resp)

# registerRouteFor(SERVER_THREAD_NAME, handleRequest)

proc initServerData*[SMsg, CMsg](): ServerData[SMsg, CMsg] =  
  result = initServer(
    startupEvents = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ],
    shutdownEvents = @[],
    sleepInMs = 0
  )