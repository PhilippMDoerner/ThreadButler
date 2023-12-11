import std/[strutils, logging]

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
  
