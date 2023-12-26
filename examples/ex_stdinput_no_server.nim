import threadButler
import std/[logging, options, strformat, os]

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

type TerminalInput = distinct string

proc requestUserInput(hub: ChannelHub) {.gcsafe, raises: [].}

threadServer("client"):
  properties:
    taskPoolSize = 4
    
  messageTypes:
    TerminalInput
    
  handlers:
    proc userInputReceived(msg: TerminalInput, hub: ChannelHub) =
      let msg = msg.string
      case msg:
      of "kill", "q", "quit":
        shutdownServer()
      else:
        debug "New message: ", msg
        runAsTask requestUserInput(hub)
    

prepareServers()

proc requestUserInput(hub: ChannelHub) {.gcsafe, raises: [].} =
    echo "\nType in a message to send to the Backend!"
    try:
      let terminalInput = readLine(stdin) # This is blocking, so this while-loop doesn't run and thus no responses are read unless the user puts something in
      echo fmt"send: Thread '{getThreadId()}' => ClientMessage(kind: TerminalInputKind, terminalInputMsg: '{terminalInput}')"
      discard hub.sendMessage(terminalInput.TerminalInput)
    except IOError, ChannelHubError, ValueError:
      echo "Failed to read in input"
    
      
proc main() =
  let hub = new(ChannelHub)
  
  requestUserInput(hub)
  let server = initServer(hub, ClientMessage)
  serverProc[ClientMessage](server)
  
  destroy(hub)

main()