import std/[asyncdispatch]
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
  if event.async:
    waitFor event.asyncHandler()
  else:
    event.syncHandler()

proc execEvents*(events: seq[Event]) =
  for event in events:
    event.exec()