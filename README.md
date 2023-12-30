# ThreadButler

> [!WARNING]  
> This library is currently in an alpha version. Some API changes may still happen. Testing as of right now consists of compiling and manually testing the examples.

#### _They're here to serve_
**ThreadButler** is a package for multithreading in applications. 

It simplifies setting up "threadServers" - threads that live as long as your application does.
These threads communicate with your main thread via messages, which trigger registered handler procs.

ThreadServers act as a "backend" for any heavy computation you do not wish to perform in your client loop. 

This package can also be used if you don't want to spawn a threadServer - the code it generates helps setting up a task-pool for one-off tasks that can send messages back when a task is done.

The message passing is done through nim's [Channels](https://nim-by-example.github.io/channels/).

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
- Typesafe message passing
- Async message handlers
- Running procs as tasks on a threadPool
- Customizable ServerLoops
- Kill-Thread mechanisms
- Startup/Shutdown events per Thread

## General Architecture

The following statements describe the architecture behind ThreadButler:
- 1 ThreadServer is an event-loop running on 1 Thread, defined by `proc runServerLoop`
- Each ThreadServer has a name called `<ThreadName>`
- Each ThreadServer has 1 dedicated Channel for messages sent to it
- All Channels are combined into a single hub, the ChannelHub, which is accessible by all threads.
- Each Thread has 1 Object Variant `<ThreadName>Message` wrapping any kind of message it can receive
- The ThreadServer's Channel can only carry instances of `<ThreadName>Message`
- Messages are wrapped in the Object Variant using helper procs `proc sendMessage`
- Each ThreadServer has its own routing `proc routeMessage`. It "unwraps" the object variant `<ThreadName>Message` and calls the registered handler proc for it.
- Each ThreadServer has its own (optional) threadPool for one-off tasks (e.g. waiting for a blocking operation).
Tasks can have access to the ChannelHub to send messages with their results if necessary.

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

#### Using ref type messages with -d:butlerThreading is not guaranteed to be thread-safe
threading/channels require a message be isolateable before sending it. This is to guarantee that the sending thread no longer accesses the memory of the message after its memory ownership was moved to another thread. You risk segfaults if you do.

However, ref-types can not be properly isolated when users pass them into the various sending procs, as the compiler can not reason about whether the user still has references to that data somewhere and may access it.

There are currently no mechanisms to do anything about this, so ThreadButler disables those isolation checks. The burden is therefore on you, the user. You must ensure to **never acccess** a message's memory after you pass it to any of ThreadButler's sending procs.