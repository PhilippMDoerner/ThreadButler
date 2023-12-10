import appster
import appster/integration/owlkettleUtils
import std/[logging, strformat, sugar]

registerTypeFor("client"):
  type Response* = distinct string
  
type Request* = distinct string
registerTypeFor("server", Request)

proc handleRequest(msg: Request, hub: ChannelHub) {.registerRouteFor: "server".} = 
  discard hub.sendMessage(Response(fmt("Response to: {msg.string}")))


proc initServerData*[SMsg, CMsg](): ServerData[SMsg, CMsg] =  
  result = initServer(
    startupEvents = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ],
    shutdownEvents = @[],
    sleepInMs = 0
  )