import threadButler
import std/[sugar, options, os]
import chronicles

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
  properties:
    shutDown = @[initEvent(() => debug "Main Thread shutting down!")]

  messageTypes:
    Response
    Input
    
  handlers:
    proc handleTerminalInput(msg: Input, hub: ChannelHub) =
      debug "On Main: ", msg = msg.string
      case msg.string:
      of "kill":
        hub.sendKillMessage(ServerMessage)
        hub.sendKillMessage(TerminalMessage)
        shutdownServer()
      else:
        discard hub.sendMessage(msg.Request)

    proc handleResponse(msg: Response, hub: ChannelHub) =
      debug "Finally received: ", msg = msg.string

    
threadServer(SERVER_THREAD):
  properties:
    shutDown = @[initEvent(() => debug "Server shutting down!")]

  messageTypes:
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      debug "On Server: ", msg = msg.string
      discard hub.sendMessage(Response("Handled: " & msg.string))

    
threadServer(TERMINAL_THREAD):
  properties:
    shutDown = @[initEvent(() => debug "Main Thread shutting down!")]



prepareServers()

# ======= Define Custom ServerLoop for Terminal Thread =======
proc runServerLoop(data: Server[TerminalMessage]) {.gcsafe.} =
  debug "Starting up custom Server Loop"
  while keepRunning():
    let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
    debug "From Terminal ", terminalInput
    discard data.hub.sendMessage(terminalInput.Input)
    
    let msg: Option[TerminalMessage] = data.hub.readMsg(TerminalMessage)
    if msg.isSome() and msg.get().kind == KillTerminalKind:
      data.hub.clearServerChannel(TerminalMessage)
      break

# ======= Define ServerLoop for Main Thread =======
proc runMainLoop(hub: ChannelHub) =
  while keepRunning():
    let msg: Option[MainMessage] = hub.readMsg(MainMessage)
    if msg.isSome():
      try:
        routeMessage(msg.get(), hub)
      except KillError:
        hub.clearServerChannel(MainMessage)
        debug "Cleared MainMessage"
        break
      
      except CatchableError as e:
        error "Message caused Exception", msg = msg.get()[], error = e.repr
        
    sleep(5)

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD):
    hub.withServer(TERMINAL_THREAD):
      runMainLoop(hub)
  
  destroy(hub)

main()