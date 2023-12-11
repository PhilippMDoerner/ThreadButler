import threadButler
import threadButler/integration/owlkettleUtils
import std/[logging, strformat, sugar]

registerTypeFor("client"):
  type Response* = distinct string
  
registerTypeFor("server"):
  type Request* = distinct string

proc handleRequest*(msg: Request, hub: ChannelHub) {.registerRouteFor: "server".} = 
  let resp = Response(fmt("Response to: {msg.string}"))
  discard hub.sendMessage(resp)


proc initServerData*[SMsg, CMsg](): ServerData[SMsg, CMsg] =  
  result = initServer(
    startupEvents = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname] "))),
      initEvent(() => debug "Server startin up!")
    ],
    shutdownEvents = @[],
    sleepInMs = 0
  )