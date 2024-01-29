import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# ThreadButler Compilation flags
ThreadButler provides various compilation flags as options.

This page serves as a reference list for all of them.

Flag | Example | Description
---|---|---
butlerDebug     | -d:butlerDebug                | Prints all generated code to the terminal
butlerThreading | -d:butlerThreading            | Changes the underlying implementation from using system.Channels to threading/channels.Chan
butlerLogLevel  | -d:butlerLogLevel='lvlDebug'  | Sets the internal log level for threadButler (Based on std/logging's [Level](https://nim-lang.org/docs/logging.html#Level)). All logging calls beneath that level get removed at compile time. Defaults to "lvlerror".
butlerDocs      | -d:butlerDocs                 | Internal Switch. Solely used to avoid actually running example-code when compiling docs with examples.
butlerDocsDebug | -d:butlerDocsDebug            | Internal Switch. Solely used to avoid doc compilation bugs introduced by other libraries (does not apply to nimibook docs).
## butlerThreading (! experimental !)
Normally threadButler uses [system.Channel](https://nim-lang.org/docs/system.html#Channel) for communication through the ChannelHub.

`butlerThreading` is an experimental flag that changes the used channel type
to [threading/channels.Chan](https://nim-lang.github.io/threading/channels.html#Chan).

This should provide better performance in some scenarios, as `Channel` always does a deep copy of any message sent from one thread to another.
With `Chan` you might be able to avoid copying in some scenarios, as it may simply move ownership of the message-memory from sender- to receiver-thread.

Note that while similar, `Channel` instances are **growable message-queues**, meaning it is unlikely that you will ever drop a message.
`Channel` will simply allocate more memory for its growing message-queue as needed.

`Chan` instances however are **fixed-size message-queues**.
Therefore, should a threadServer not work through messages quickly enough and cause its `Chan` to fill up to its capacity, it will drop messages (which you can notice by the boolean "sendMessage" procs return).

You may therefore want to think about what should happen if a message is dropped, e.g. implement a "retry" mechanism in some scenarios, or just letting it drop in others.
"""

nbSave