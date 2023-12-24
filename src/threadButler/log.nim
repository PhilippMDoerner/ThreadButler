import std/[strutils, logging]

##[

A simple module handling logging within threadbutler, using std/logging.
The log-level is set at compile-time using the `-d:butlerloglevel=<LogLevelEnumName>` (e.g. `-d:butlerloglevel='lvlAll'`) compiler flag.
Logging at a specific level is compiled in or out based on the log-level allowed at compile-time.

This module is only intended for use within threadButler and for integrations.
]##

const BUTLER_LOG_LEVEL* {.strdefine: "butlerloglevel".}: string = "lvlerror"

const LOG_LEVEL*: Level = parseEnum[Level](BUTLER_LOG_LEVEL)

proc debug*(message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlDebug:
      try:
        logging.debug message
      except Exception:
        discard

proc notice*(message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlNotice:
      try:
        logging.notice message
      except Exception:
        discard


proc warn*(message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlWarn:
      try:
        logging.warn message
      except Exception:
        discard

proc error*(message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlError:
      try:
        logging.error message
      except Exception:
        discard


proc fatal*(message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= lvlFatal:
      try:
        logging.fatal message
      except Exception:
        discard