import std/[sets, sequtils]
import ./[channelHub, events]
import chronos
when not defined(butlerDocsDebug): # See https://github.com/status-im/nim-chronos/issues/499 
  import chronos/threadsync

  type Server*[Msg] = object ## Data representing a single threadServer
    hub*: ChannelHub ## The ChannelHub. Set internally by threadButler
    msgType*: Msg ## The Message-Wrapper-Type of all messages that this threadServer receives. Set internally by threadButler
    startUp*: seq[Event] ## parameterless closures to execute before running the server
    shutDown*: seq[Event] ## parameterless closures to execute after when the server is shutting down
    taskPoolSize*: int = 2 ## The number of threads in the threadPool that execute tasks. Needs to be at least 2 to have a functioning pool. It must because the thread of the threadServer gets counted as part of the pool but will not contribute to working through tasks.
    signalReceiver*: ThreadSignalPtr ## For internal usage only. Signaller to wake up thread from low power state.

else:
  type Server*[Msg] = object ## Data representing a single threadServer
    hub*: ChannelHub ## The ChannelHub. Set internally by threadButler
    msgType*: Msg ## The Message-Wrapper-Type of all messages that this threadServer receives. Set internally by threadButler
    startUp*: seq[Event] ## parameterless closures to execute before running the server
    shutDown*: seq[Event] ## parameterless closures to execute after when the server is shutting down
    taskPoolSize*: int = 2 ## The number of threads in the threadPool that execute tasks. Needs to be at least 2 to have a functioning pool. It must because the thread of the threadServer gets counted as part of the pool but will not contribute to working through tasks.
  
type Property* = enum ## The fields on `Server`_ that can be set via a `properties` section
  startUp
  shutDown
  taskPoolSize
const PROPERTY_NAMES*: HashSet[string] = Property.toSeq().mapIt($it).toHashSet()

type Section* = enum
  MessageTypes = "messageTypes" ## Section that defines all message-types that a threadServer can receive.
  Properties = "properties" ## Section for the various definable `Property`_ fields of a threadServer.
  Handlers = "handlers" ## Section for all procs that handle the various message-types this threadServer can receive.
const SECTION_NAMES*: HashSet[string] = Section.toSeq().mapIt($it).toHashSet()

when not defined(butlerDocs):
  proc waitForSendSignal*[Msg](server: Server[Msg]) = 
    ## Causes the server to work through its remaining async-work
    ## and go into a low powered state afterwards. Receiving a singla
    ## will wake the server up again.
    waitFor server.signalReceiver.wait()