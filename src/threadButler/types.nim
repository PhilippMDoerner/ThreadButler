import std/[sets, sequtils]
import ./[channelHub, events]

type Server*[Msg] = object ## Data representing a single threadServer
  hub*: ChannelHub ## The ChannelHub. Set internally by threadButler
  msgType*: Msg ## The Message-Wrapper-Type of all messages that this threadServer receives. Set internally by threadButler
  sleepMs*: int = 5 ## Defines the amount of time spent each event-loop iteration on the async-event-loop. Increase when higher latency is acceptable for better idle efficiency
  startUp*: seq[Event] ## parameterless closures to execute before running the server
  shutDown*: seq[Event] ## parameterless closures to execute after when the server is shutting down
  taskPoolSize*: int = 2 ## The number of threads in the threadPool that execute tasks.

type Property* = enum ## The fields on `Server`_ that can be set via a `properties` section
  sleepMs
  startUp
  shutDown
  taskPoolSize
const PROPERTY_NAMES*: HashSet[string] = Property.toSeq().mapIt($it).toHashSet()

type Section* = enum
  MessageTypes = "messageTypes" ## Section that defines all message-types that a threadServer can receive.
  Properties = "properties" ## Section for the various definable `Property`_ fields of a threadServer.
  Handlers = "handlers" ## Section for all procs that handle the various message-types this threadServer can receive.
const SECTION_NAMES*: HashSet[string] = Section.toSeq().mapIt($it).toHashSet()
