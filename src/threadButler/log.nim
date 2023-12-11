import std/[strutils, logging]

## A simple module handling logging within threadbutler, using std/logging.
## The log-level is set at compile-time using the `-d:buglerloglevel=<LogLevelEnumName>` flag.
## Logging at a specific level is compiled in or out based on the log-level allowed at compile-time.

const BUTLER_LOG_LEVEL* {.strdefine: "butlerloglevel".}: string = "lvlerror"

const LOG_LEVEL*: Level = parseEnum[Level](BUTLER_LOG_LEVEL)

template debug*(message: string) =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlDebug:
      debug message


template notice*(message: string) =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlNotice:
      notice message


template warn*(message: string) =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlWarn:
      warn message


template error*(message: string) =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlError:
      error message


template fatal*(message: string) =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlFatal:
      fatal message
  
