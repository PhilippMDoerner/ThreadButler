import nimib, nimibook

nbInit(theme = useNimibook)

nbText: """
# Generated Code
ThreadButler generates a fair amount of types and procs.
This page exists as a reference to list all of them out and provide doc-comments for them.

The sections are in the order that the type/proc-code-snippets are emitted by threadButler.

## `type <ThreadName>Kinds = enum`
Enum representing all kinds of messages a given ThreadServer can receive.
It is used to generate the Message-Wrapper-Type.

Includes 1 kind per registered type + [1 Kill<ThreadName>Kind](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#killKindName%2CThreadName)

## `type <ThreadName>Message = object`
The Message-Wrapper-Type.
Object variant capable of wrapping any message-type that can be sent to a ThreadServer.
Instances of this type are always sent to the Channel associated with it and thus to the associated ThreadServer.

## proc sendMessage
A proc of shape: `proc sendMessage*(hub: ChannelHub, msg: sink `msgType`): bool`

Tries to send a message through the ChannelHub. 
Returns true if that succeeded, false if it didn't - because the channel was full - and the message was dropped.

## [proc sendKillMessage](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#genSendKillMessageProc%2CThreadName)
Procs generated to send killMessages to individual servers.

## [proc initServer](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#genInitServerProc%2CThreadName)
A proc used by threadButler internally to instantiate `Server`
objects.

## var <threadname>ButlerThread
A global mutable variable containing a thread.
This is for the thread to run specifically the threadServer associated with `threadname`. 

## [proc new(ChannelHub)](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#genNewChannelHubProc)
Constructor for ChannelHub.
Only calls this proc once to have a single instance that you pass around.

## [proc destroy(ChannelHub)](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#genDestroyChannelHubProc)
Destructor for ChannelHub.
Only call this proc once to destroy the single ChannelHub instance that you have.

## [proc routeMessage](https://philippmdoerner.github.io/ThreadButler/htmldocs/threadButler/codegen.html#genMessageRouter%2CThreadName%2Cseq%5BNimNode%5D%2Cseq%5BNimNode%5D)
The routing proc generated per threadserver.

"""

nbSave()