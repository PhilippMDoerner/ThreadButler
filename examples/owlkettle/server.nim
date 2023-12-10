import appster
import appster/integration/owlkettleUtils
import std/[logging, strformat, sugar]

type Response* = distinct string
type Request* = distinct string

proc handleRequest(msg: Request, hub: ChannelHub) {.route: "server".} = 
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