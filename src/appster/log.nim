import std/[strutils, strformat, logging]

const APPSTER_LOG_LEVEL* {.strdefine: "appsterloglevel".}: string = "lvlerror"

const LOG_LEVEL*: Level = parseEnum[Level](APPSTER_LOG_LEVEL)

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
  
