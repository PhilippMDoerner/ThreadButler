import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# First example

Note: Throughout this code example it may be helpful to also have the **glossary** page open.
It defines various terms used throughout the book (e.g. `Message-Wrapper-Type`).

If you want to first look at the code in its entirety, take a look at the full example at the bottom of the page.

## The Example
Our example is a main thread that runs a "client" that reads from the terminal.
It either sends a message to a "server" or shuts down the program based on what the terminal input is.

So we have 2 threads, each running a single threadServer:
  1) A client threadServer listening to user input in the terminal and messages from the backend server
  2) A backend threadServer listening for messages from the client and sending responses

But before we can define them, we first need to know the messages we're about to send around.


## Message Types
```nim
type Response = distinct string
type Request = distinct string
```
This defines a message type for messages we want to send from the client to the server (`Request`)
and one for sending back messages from the server to the client (`Response`)

Basically, before anything, we need to define the types of the messages that we want to send around.
This is essential, as we later connect those message types to the threadServers
and use them in our handler procs.


## The Client
With the message types defined, we now can define our client threadServer:
```nim
import std/[sugar, options, strformat, os]
import threadButler

threadServer("client"):
  messageTypes:
    Response
    
  handlers:
    proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
      echo "On Client: ", msg.string
```
This defines a threadServer with the threadname "client". 
That name is important, because based on it threadButler will generate a lot of code and derive variable- and typenames from it.
For an overview over all the things it generates, see the [docs](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#threadServer.m%2Cstaticstring%2Cuntyped)

We see here that "client" has 2 sections:
  1) messageTypes
  2) handlers

### messageTypes
The messageTypes section defines one or more types of messages that "client" can receive (here only `Response`).

Types in the messageType block **must** be unique. 
That means that a type can only be registered *for one threadServer*.

This is why we defined `Response` and `Request` as distinct strings earlier.
Even if they're both just strings, you can not register the type `string` for both
"client" and "server" (which we will define later).

This also gives threadButler important information:
ThreadButler now knows that `Response` is only registered for and can only be received by "client".
So when we later want to send a message of the `Response` type, threadButler knows that it is intended for "client".

### handlers
The handlers section defines how to handle a message of a specific message type that "client" may receive.

It is a bunch of procs that **must** cover all types defined in `messageTypes`.
ThreadButler will tell you at compile-time if you forgot to define a handler for one of the types or added a handler whose type is not mentioned in `messageTypes`.

These procs must have this signature:
```nim
proc <procName>(msg: <YourMsgType>, hub: ChannelHub)
```
Where `<procName>` can be whatever you want and `<YourMsgType>` is one of the types in `messageTypes`.

This also is our first encounter with `ChannelHub`.
We will see it quite often, as sending a message is only possible through `ChannelHub`, which is an object
shared and used by all threadServers.


## The Server
With our client defined, lets define our server which shall receive `Request` messages and in turn
send back `Response` messages.

```nim
threadServer("server"):
  properties:
    startUp = @[initEvent(() => echo "Server startin up!")]
    shutDown = @[initEvent(() => echo "Server shutting down!")]
  
  messageTypes:
    Request
    
  handlers:
    proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
      echo "On Server: ", msg.string
      discard hub.sendMessage(Response("Handled: " & msg.string))
```

We see the familiar "messageTypes" which defines that "server" can receive `Request` messages.
There's also the expected "handler" with `handleRequestOnServer` telling us what happens when a `Request`
message is received.

However, properties is new!

The properties section is where you can define special properties that influence a threadServer's behaviour unrelated to messages and their handling.
The properties we set here are `startUp` and `shutDown`, which define events that get executed before/after the server has run.

In this case we're just writing some text to the terminal before and after the server runs.
Other useful applications for them are:
  - Initializing/closing resources required by this threadServer
  - Initializing Loggers for the server

There are more properties that you can define. For more details see the "threadServer" page.

## Finishing touches
With our servers defined, we can now bring it all together.

```nim
prepareServers()

let hub = new(ChannelHub)

withServer(hub, "server"):
  while IS_RUNNING:
    echo "\nType in a message to send to the Backend!"
    let terminalInput = readLine(stdin)
    case terminalInput
    of "kill", "q", "quit":
      break
    else:
      let msg = terminalInput.Request
      discard hub.sendMessage(msg)
    
    sleep(100) 
    
    let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
    if response.isSome():
      routeMessage(response.get(), hub)

destroy(hub)
```
That's quite a lot at once, let's look at the sections individually.

### prepareServers
The first thing that stands out is `prepareServers`.

That is a special macro from threadButler that generates some of the code that it can only generate
once all threadServers were defined.

For an overview over all the things it generates, look at the [docs](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#prepareServers.m).

### new(ChannelHub)
This instantiates the one instance of `ChannelHub` that will be used everywhere.

### withServer
"server" is then started at the beginning of `withServer` and automatically shut down once the scope of `withServer` ends.

Inside of the scope of `withServer` we can then define the "event-loop" code that should run on the main-thread which has executed the code so far.

We're using the global `IS_RUNNING` variable of threadButlers. It is a value used and shared by the default event-loop that threadButler provides. 
Setting it to false shuts down all servers after their current event-loop iteration finishes.

We then stop the loop to listen for user-input and do not continue until user-input was provided.

If the user types in "kill", "q" or "quit" this will break the main-event-loop, we reach the end of `withServer`, "server" shuts down and the program ends.

If the user types in anything else, our main-event-loop (aka "client") will send a `Request` message to "server" with the terminal input.
It will then sleep for 100ms (to give "server" plenty of time to reply) and check for messages send to "client" on the ChannelHub.

Note how we do this using `ClientMessage`. 
This is a type generated by `threadServer` that can contain any of the messages sent to "client".
The name of this type is inferred from the name we provided earlier, "client".
For more details see the "Docs for generated code" page.

If we have a message, we then handle it using the also generated `routeMessage` convenience proc.
It will unpack `ClientMessage` to `Response` and route it to `handleResponseOnClient`, which then handles the message as we defined earlier.


## Full example
"""

nbCode:
  import std/[sugar, options, strformat, os]
  import threadButler

  const CLIENT_THREAD = "client"
  const SERVER_THREAD = "server"
  type Response = distinct string
  type Request = distinct string

  # === DEFINE YOUR THREADSERVERS === #
  threadServer(CLIENT_THREAD):
    messageTypes:
      Response
      
    handlers:
      proc handleResponseOnClient(msg: Response, hub: ChannelHub) =
        echo "On Client: ", msg.string

  threadServer(SERVER_THREAD):
    properties:
      startUp = @[initEvent(() => echo "Server startin up!")]
      shutDown = @[initEvent(() => echo "Server shutting down!")]
    
    messageTypes:
      Request
      
    handlers:
      proc handleRequestOnServer(msg: Request, hub: ChannelHub) = 
        echo "On Server: ", msg.string
        discard hub.sendMessage(Response("Handled: " & msg.string))

  prepareServers()

  # === Bringing it all together === #
  when defined(butlerDocs):
    IS_RUNNING = false ## Needed so that compiling the docs does not run the server

  let hub = new(ChannelHub)
  hub.withServer(SERVER_THREAD):
    while IS_RUNNING:
      echo "\nType in a message to send to the Backend!"
      # This is blocking, so this while-loop stalls here until the user hits enter. 
      # Thus the entire loop only runs once whenever the user hits enter. 
      # Thus it can only receive one message per enter press.
      let terminalInput = readLine(stdin)
      case terminalInput
      of "kill", "q", "quit":
        hub.sendKillMessage(ServerMessage)
        break
      else:
        let msg = terminalInput.Request
        discard hub.sendMessage(msg)
      
      ## Guarantees that the server has responded before we listen for user input again. 
      ## This is solely for neater logging when running the example.
      sleep(100) 
      
      let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
      if response.isSome():
        routeMessage(response.get(), hub)

  destroy(hub)

nbSave()