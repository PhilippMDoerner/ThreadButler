import nimib, nimibook

nbInit(theme = useNimibook)

nbText: """
# [Examples](https://github.com/PhilippMDoerner/ThreadButler/tree/main/examples)
This is a list of further examples that show off various details of ThreadButler.
You can also find them in their github folder. Their filenames have the `ex_` prefix.

## [Async](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/ex_stdinput_async.nim)
ThreadButlers own eventLoop comes with simple support for asynchronous handlers.

Just annotate your handler with {.async.} and the code generated by `generateRouting` will adjust to account for that.

## [Custom Event Loops](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/ex_stdinput_customloop.nim)
ThreadButler allows replacing the default event-loop it uses for ThreadServers with your own.

Therefore, if you need to supply your own, e.g. because you need to run the [event-loop from a GUI framework on that thread](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/owlkettle/ex_owlkettle_customloop.nim), you can do so.

Just overload the `runServerLoop` proc.

## [Tasks](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/ex_stdinput_tasks.nim)
ThreadButler allows executing tasks in a separate thread using [status-im/nim-taskpools](https://github.com/status-im/nim-taskpools).

Just define the `taskPoolSize` property on `threadServer`.
ThreadButler uses this to determine the size of the thread-local thread-pool.
That threadpool works on tasks spawned by your threadServer.

You can turn any proc-call into a task by using the `spawn` syntax:
```nim
runAsTask myProc()
runAsTask myProc(param1, param2)
```

## [No Server](https://github.com/PhilippMDoerner/ThreadButler/blob/main/examples/ex_stdinput_no_server.nim)
ThreadButler can be useful even without running a dedicated thread as a server.

This example uses ThreadButlers code-generation to just set up a threadpool that sends messages back and handling those automatically.
No threadServer is spawned, just the main-thread and a task-pool.
"""

nbSave()