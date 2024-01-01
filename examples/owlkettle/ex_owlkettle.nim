import std/[options]
import threadButler
import threadButler/integration/owlButler
import owlkettle
import ./widget

proc main() =
  let hub = new(ChannelHub)

  hub.withServer(SERVER_THREAD):
    let listener = createListenerEvent(hub, AppState, CLIENT_THREAD)
    owlkettle.brew(
      gui(App(server = hub)),
      startupEvents = [listener]
    )  
  
  hub.destroy()

main()
