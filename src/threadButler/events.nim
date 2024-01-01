import std/[asyncdispatch, sugar]
import taskpools
import chronicles

##[
Defines the Events that should happen when starting a thread-server or when shutting it down
]##

type
  AsyncEvent* = proc(): Future[void] {.closure, gcsafe.}
  SyncEvent* = proc() {.closure, gcsafe.}

  Event* = object      ## `startup` or `shutdown` event which is executed once.
    case async*: bool
    of true:
      asyncHandler*: AsyncEvent
    of false:
      syncHandler*: SyncEvent

func initEvent*(handler: AsyncEvent): Event =
  ## Initializes a new asynchronous event. 
  Event(async: true, asyncHandler: handler)

func initEvent*(handler: SyncEvent): Event =
  ## Initializes a new synchronous event. 
  Event(async: false, syncHandler: handler)

proc exec*(event: Event) {.inline.} =
  ## Executes a single event
  if event.async:
    waitFor event.asyncHandler()
  else:
    event.syncHandler()

proc execEvents*(events: seq[Event]) =
  ## Executes a list of events
  for event in events:
    event.exec()
    
## Premade Events
template initCreateTaskpoolEvent*(size: int, taskPoolVar: untyped): Event =
  ## Convenience Utility for status/nim-taskpools.
  ## Creates an Event that creates/initializes the threadpool in the variable contained in `taskPoolVar`.
  block:
    proc createTaskpool() =
      taskPoolVar = Taskpool.new(numThreads = size)
      debug "Create Threadpool", poolPtr = cast[uint64](taskPoolVar)
    initEvent(() => createTaskpool()) 

template initDestroyTaskpoolEvent*(taskPoolVar: untyped): Event =
  ## Convenience Utility for status/nim-taskpools.
  ## Creates an Event that destroys the threadpool in the variable contained in `taskPoolVar`.
  block:
    proc destroyTaskpool() =
      taskPoolVar.shutDown()
      debug "Destroy Threadpool", poolPtr = cast[uint64](taskPoolVar)

    initEvent(() => destroyTaskpool()) 