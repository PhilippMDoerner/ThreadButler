import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# Integrations

This page provides examples for the various frameworks that
threadButler provides special integration utilities for.

## [Owlkettle](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/owlkettle/ex_owlkettle.nim)
Integration with owlkettle works by threadButler essentially not providing an event-loop.
Instead it hooks into owlkettle's GTK event-loop to listen for and react to messages.

The following "Special rules" need to be kept in mind when running ThreadButler with owlkettle:
  - Add a field to `App` for the `Server` instance for the owlkettle thread.
  - Create a listener startup event and add it to the `brew` call
  - Use [`owlThreadServer`](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/integrations/owlCodegen.html#owlThreadServer) instead of `threadServer`, but only for your owlkettle thread <br>
      Note: `owlThreadServer` requires handlers to have a different proc signature. See the reference docs for more details.
  - Use [`prepareOwlServers`](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/integrations/owlCodegen.html#prepareOwlServers) instead of `prepareServers`

In order to make data from messages available within owlkettle, add more fields
to `AppState`. 
You can then assign values from your messages to those fields and use them 
in your `view` method.  

## [Owlkettle - Custom Event Loop](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/owlkettle/ex_owlkettle_customloop.nim)
Demonstrates how to put owlkettle's GTK event-loop into its own threadServer, essentially turning this into a 3 threads setup
with a main-thread, a thread for owlkettle and a thread for the server.

Listens for user-input from the terminal and sends it to the owlkettle thread. 
"""

nbSave