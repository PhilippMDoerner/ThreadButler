import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# ThreadServer
This is a more in-depth description over the `threadServer` block.

ThreadServers are basically just threads running a while-loop (aka event-loop).
The code to run them is generated via the `threadServer` and `prepareServers` macro.

## `threadServer`
The `threadServer` macro accepts any of the following blocks:
  - properties
  - messageTypes
  - handlers

### properties
The properties section is where you can define special properties that influence a threadServer's behaviour unrelated to messages and their handling.

Properties are used to generate the `Server` instance representing a threadServer.
See [`Server`s reference docs](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/types.html#Server) for what each field means.

The properties we set here are `startUp` and `shutDown`, which define events that get executed before/after the server has run.


### messageTypes
The messageTypes section defines one or more types of messages that a given threadServer can receive.

Types in the messageType block **must** be unique. 
That means that a type can only be registered *for one threadServer*.
If a type is registered multiple times, threadButler will error out at compile-time.

### handlers
The handlers section defines how to handle a message of a specific message type that the threadServer may receive.

It is a bunch of procs that **must** cover all types defined in `messageTypes`.
ThreadButler will tell you at compile-time if you forgot to define a handler for one of the types or added a handler whose type is not mentioned in `messageTypes`.

Generally these procs must have this signature:
```nim
proc <procName>(msg: <YourMsgType>, hub: ChannelHub)
```
Where `<procName>` can be whatever you want and `<YourMsgType>` is one of the types in `messageTypes`.

This is because the `routeMessage` proc that will be generated relies on the handlers having this signature.

However, integrations may provide their own `routeMessage` procs (generated by their own `prepareServer` variation).
This can allow for handler-procs with different signatures.

"""

nbSave