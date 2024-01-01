import std/[options, tables]
import threadButler
import threadButler/integration/owlButler
import owlkettle
import ./widget
import chronicles

proc runServerLoop(client: Server[ClientMessage]) {.gcsafe.} =
  # Gui Thread within the context of having a server thread
  echo "Clientloop"
  let listener = createListenerEvent(client.hub, AppState, CLIENT_THREAD)
  {.gcsafe.}:
    owlkettle.brew(
      gui(App(server = client.hub)),
      startupEvents = [listener]
    )

proc main() =
  let hub = new(ChannelHub)
  
  hub.withServer(SERVER_THREAD): # Runs "Backend" Server
    hub.withServer(CLIENT_THREAD): # Runs owlkettle gui
      while IS_RUNNING:
        let terminalInput = readLine(stdin)
        discard hub.sendMessage(terminalInput.Response)
  destroy(hub)

main()
