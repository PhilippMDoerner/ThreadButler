import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# Glossary
The core idea behind ThreadButler is to define **ThreadServers**.

**ThreadServers** are long-running threads that receive and can send **messages** from other threads. 

**ThreadServers** have **ThreadNames**.

**ThreadServers** run **server/event-loops** which define what the threadServer does. ThreadButler provides one by default, but it can be overwritten.

**ThreadServers** can have **threadpools** to execute short-lived **tasks**.

**ThreadNames** are used to associate **handlers** and **types** (or **message-types**) with them.

The process of associating them and informing ThreadButler about which ThreadNames exist is called **registering**.

**Messages** are any instances of a registered **message-type** that are being sent to the ChannelHub.

**ThreadNames** also define the name of **Message-Wrapper-types**.

**Message-Wrapper-types** are object variants that are generated from and thus can contain any message-type of one specific **ThreadServer**.

**Message-Wrapper-types** therefore identify to which **ThreadServer** a message of a specific **message-type** is supposed to go.

**Routing-procs** are generated procs that route a **message** received by a **ThreadServer** to its **handler**.

**Sending** a message means calling a generated `sendMessage` proc on a message.

**KillMessages** are special messages that can be sent via generated `sendKillMessage` procs to shut down a **ThreadServer**.

**Channel** is a queue of messages to a given **ThreadServer**. Each **ThreadServer** has its own **Channel**.
That **Channel** only carries the **1 Message-wrapper-type** specific for that **ThreadServer**. 

**ChannelHub** is an object containing all **channels**. It is the central place through which all **messages** are sent.

**Handlers** are user-defined procs that get **registered** with ThreadButler. They get called when a **ThreadServer** receives a **message** for their type.
They may be async, but must follow this proc pattern:
```nim
proc <someName>(msg: <YourType>, hub: ChannelHub)
```
"""

nbSave()