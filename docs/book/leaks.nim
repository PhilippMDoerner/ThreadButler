import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# ThreadButler Memory Leak FAQ
ThreadButler is checked for memory leaks regularly using [address sanitizers](https://github.com/google/sanitizers/wiki/AddressSanitizer) and does provide a leak-free experience on its own.

However, due to its multi-threaded nature, it is very easy to introduce memory leaks yourself, particularly when a thread dies without cleaning up all of its ref-variables.

### How big of a problem is this for me?
Generally it is unlikely to be a problem unless you use threadButler for starting and stopping the same `threadServer`s multiple times throughout the runtime of your program.

If you don't do that, it is unlikely to be a problem since the `threadServer`s shutting down typically means the application is about to end, leading to a "leak" of memory only at the end of the application.

It may however annoy you if you want to use tools such as address sanitizers or valgrind to check your own program for memory leaks.

### How do can I see if I have a problem?
You can use valgrind or address sanitiziers. This project itself is only validated using address sanitizers.

For detailed docs on their general usage refer to the link above. 

As an example for nim, you can compile your program with a command like this:
```txt
nim r 
    --cc:clang 
    --mm:<Your used memory management option>
    --debugger:native 
    -d:release 
    -d:useMalloc # Sets the allocator doe Malloc for address sanitizers
    --passc:"-fsanitize=address -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer" # Tells Clang to use address sanitizers with frame pointers for better debugging
    --passl:"-fsanitize=address -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer" # Tells the linker to use address sanitizers with frame pointers for better debugging
    <your nim file>
```

Compile and run your program with the command above and after exiting you should either get a bunch of stacktraces (if you have leaks) or nothing.

You then have to go through the stacktraces and look for ref-type instances that might not be cleaned up along the way.
You'll want to keep an eye out for the following:

- threadVariables of ref-types, used either by yourself, a library, or a library of a library. [Nim does not clean those up automatically yet](https://github.com/nim-lang/Nim/issues/23165)
- Generally any ref-type variable that you might be sending to another thread
- Generally any memory where you allocate memory directly
- Anywhere you have `pointer`

### I found the source of a leak, what now?

For general variables that leak the generally preferred method is calling [reset](https://nim-lang.org/docs/system.html#reset%2CT) on them.

Calling `=destroy` on them or setting these variables to `nil` is also a valid strategy.

Some variables may not have a `=destroy` hook defined for them. 
In those cases look for specific procs in the library you're using about de-initializing them.

### The leaking variable is a private variable from a library I use, how do I access it?
Ideally you inform the library author of the leaky behaviour their library causes in multi-threaded constellations and they provide a solution.

In the meantime, you can use imports with the `all` pragma to force nim to import all symbols from a module, including privates ones.

Example: `import std/times {.all.}`
"""

nbSave()