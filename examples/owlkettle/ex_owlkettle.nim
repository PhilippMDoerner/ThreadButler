import std/[options, logging, strformat]
import threadButler
import threadButler/integration/owlButler
import owlkettle
import ./widget

addHandler(newConsoleLogger(fmtStr="[CLIENT $levelname] "))

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
