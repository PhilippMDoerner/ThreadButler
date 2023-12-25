# ThreadButler

> [!WARNING]  
> This library is currently in an alpha version. Some API changes may still happen. Testing as of right now consists of compiling and manually testing the examples.

#### _They're here to serve_
**ThreadButler** is a package for multithreading in applications. 

It simplifies setting up "threadServers" - threads that live as long as your application does and can be pinged with messages and send messages to any other thread themselves. 

They act as a "backend" for any heavy computation you do not wish to perform in your client loop. 

The message sending is enabled via nim's [Channels](https://nim-by-example.github.io/channels/). ThreadButler defines a shared ChannelHub that contains 1 Channel for each Thread. Those channels accept only messages for the Thread they're assigned to.

- [Documentation](https://philippmdoerner.github.io/ThreadButler/bookCompiled/index.html) (built with [nimibook](https://github.com/pietroppeter/nimibook))
- [Index](https://philippmdoerner.github.io/ThreadButler/htmldocs/theindex.html)
- [RootModule](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler.html)

## Installation

Install ThreadButler with Nimble:

    $ nimble install -y threadButler

Add ThreadButler to your .nimble file:

    requires "threadButler"

## Provided/Supported:
- Defining and spawning long-running threads with threadServers that receive and send messages 
- Typesafe message passing - A message will always be sent to the correct thread it belongs to, as determined by its type
- Async message handlers
- Running procs as tasks on a threadPool which can message results back if necessary without ever blocking
- Customizable ServerLoops
- Kill-Thread mechanisms
- Startup/Shutdown events per Thread

## General Architecture

The following statements describe the architecture behind threadButler:
- 1 ThreadServer is an event-loop running on 1 Thread
- Each ThreadServer has a name called `<ThreadName>`
- Each ThreadServer has 1 dedicated Channel for messages sent to it
- All Channels are combined into a single hub, the ChannelHub, which is accessible by all threads.
- Each Thread has 1 Object Variant `<ThreadName>Message` wrapping any kind of message it can receive
- The ThreadServer's Channel can only carry instances of `<ThreadName>Message`
- Messages are wrapped in the Object Variant using helper procs `proc sendMessage`
- Each ThreadServer has its own routing `proc routeMessage`. It "unwraps" the object variant `<ThreadName>Message` and calls the registered handler proc for it.
- Each ThreadServer has its own (optional) threadPool for one-off tasks (e.g. waiting for a blocking operation)

### General Flow of Actions

<img src="./assets/app_architecture.png">

## Special Integrations
ThreadButler provides small, simple utilities for easier integration with specific frameworks/libraries.

Currently the following packages/frameworks have such modules: 

- [Owlkettle](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/integrations/owlButler.html)

## Limitations
#### No explicit support for --mm:refc
This package is only validated for the ARC/ORC memory management strategies (--mm:arc and --mm:orc respectively).

If you are not familiar with those flags, check out the [nim compiler docs](https://nim-lang.org/docs/nimc.html).

#### Must use -d:useMalloc
Due to memory issues that occurred while running some stress-tests it is currently discouraged to use nim's default memory allocator. Use malloc with `-d:useMalloc` instead.

See [nim-lang issue#22510](https://github.com/nim-lang/Nim/issues/22510) for more context.

#### Using ref type messages with -d:butlerThreading is not supported by the framework
threading/channels require a message be isolateable.
This is not easily doable as ref-types by their nature can not be isolated, as you - the user - will still be holding on to references when passing the message.

So to send a message we would need to:
- dereference the message to make it isolateable
- send it through the threading/channel
- put the message behind a reference again on the other thread

Just so the handler-proc can be called with the appropriate type again.

This requires derefferencing the message before sending and moving the message into a reference again after sending but before invoking a registered handler. The added complexity does not seem worth it.