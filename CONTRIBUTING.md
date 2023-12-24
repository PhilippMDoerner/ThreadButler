# Contributing to ThreadButler

## Documentation
### General
The public API of any module must have doc comments.

Private procs that are used to generate units of code (e.g. a proc or a type) should have doc comments, even if only for maintainers.

### Wording
Words are important. Introducing new specific terms may require explanation to users of this library risk confusing them.

Therefore, if a new term is introduced, consider adding an explanation for it to the [Glossary](https://philippmdoerner.github.io/ThreadButler/bookCompiled/glossary.html).

Also try to limit terms used to those in the glossary for consistency.

#### Changes procs inferring names from ThreadName
Many identifiers are inferred from a given `ThreadName` that the user provides via macro.
The procs that are the central points for these operations are at the start of `codegen`.

If the output of one of these procs is changed, then also check the doc comments of every proc using it as well, as they might now require updating. Also update `generatedCodeDocs.nim`.

### Features
Consider whether a new given feature might benefit from being provided as an example. Examples are part of the test-suite as well as acting as documentation and thus will enable better stability.

When adding an Example, also add it to the [nimibook examples page](https://philippmdoerner.github.io/ThreadButler/bookCompiled/examples.html)

### Compiler Flags
When contributing code that introduces new compiler flags, make sure they are mentioned and explained in the [nimibook docs page on flags](https://philippmdoerner.github.io/ThreadButler/bookCompiled/flags.html)

Compiler flags are typically prefixed with `butler`.

### Generated Code
When contributing features that generate new code, make sure that they are mentioned and documented in the [nimibook docs page for generated code](https://philippmdoerner.github.io/ThreadButler/bookCompiled/generatedCodeDocs.html)

## Coding Style
### General
This project uses camelCase.

Contants are written using SCREAMING_CASE.

### Macros
This project aggressively validates every step of the way that nodes are what they are assumed to be.

If a proc acting on NimNodes or a macro requires NimNodes to be of a certain kind, use `expectKind` (for macros) and `assertKind` (for procs) to figure out as early as possible and make macro-debugging easier.

When suing `expectKind`, please provide actionable user-facing error messages.