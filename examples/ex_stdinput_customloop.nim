import threadButler
import std/[sugar, logging, options, strformat, os, asyncdispatch]

addHandler(newConsoleLogger(fmtStr="[MAIN $levelname    ] "))

const MAIN_THREAD = "main"
const SERVER_THREAD = "server"
const TERMINAL_THREAD = "terminal"
type Response = distinct string
type Pong = distinct int
type Input = distinct string
type Ping = distinct int 
type Request = distinct string

# ======= Define Message Types =======
threadServer(MAIN_THREAD):
  messageTypes:
    Response
    Pong
    Input
    
  handlers:
    proc handleTerminalInput(msg: Input, hub: ChannelHub) =
      debug "On Main: ", msg.string
      case msg.string:
      of "kill":
        hub.sendKillMessage(ServerMessage)
        hub.sendKillMessage(TerminalMessage)
        shutdownServer()
      else:
        discard hub.sendMessage(msg.Request)

    proc ping(msg: Pong, hub: ChannelHub) {.async.} =
      await sleepAsync(10_000)
      discard hub.sendMessage(msg.Ping)

    proc handleResponse(msg: Response, hub: ChannelHub) =
      debug "Finally received: ", msg.string

    
threadServer(SERVER_THREAD):
  properties:
    startUp = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[SERVER $levelname  ] "))),
    ]
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Ping 
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      debug "On Server: ", msg.string
      discard hub.sendMessage(Response("Handled: " & msg.string))

    proc pong(msg: Ping, hub: ChannelHub) {.async.} =
      await sleepAsync(10_000)
      discard hub.sendMessage(msg.Pong)

    
threadServer(TERMINAL_THREAD):
  properties:
    startUp = @[
      initEvent(() => addHandler(newConsoleLogger(fmtStr="[TERMINAL $levelname] "))),
    ]


prepareServers()

# ======= Define Custom ServerLoop for Terminal Thread =======
proc runServerLoop(data: Server[TerminalMessage]) {.gcsafe.} =
  debug "Starting up custom Server Loop"
  while IS_RUNNING:
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    debug "From Terminal ", terminalInput
    discard data.hub.sendMessage(terminalInput.Input)
    
    let msg: Option[TerminalMessage] = data.hub.readMsg(TerminalMessage)
    if msg.isSome() and msg.get().kind == KillTerminalKind:
      break

# ======= Define ServerLoop for Main Thread =======
proc runMainLoop(hub: ChannelHub) =
  while IS_RUNNING:
    let msg: Option[MainMessage] = hub.readMsg(MainMessage)
    if msg.isSome():
      try:
        routeMessage(msg.get(), hub)
      except KillError:
        break
      
      except CatchableError as e:
        error(fmt"Message '{msg.get().repr}' Caused exception: " & e.repr)
        
    sleep(5)

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD):
    discard hub.sendMessage(0.Ping)
    hub.withServer(TERMINAL_THREAD):
      runMainLoop(hub)
  
  destroy(hub)

main()