import std/[strutils, logging]
export logging
##[

A simple module handling logging within threadbutler, using std/logging.
The log-level is set at compile-time using the `-d:butlerloglevel=<LogLevelEnumName>` (e.g. `-d:butlerloglevel='lvlAll'`) compiler flag.
Logging at a specific level is compiled in or out based on the log-level allowed at compile-time.

This module is only intended for use within threadButler and for integrations.
]##

const BUTLER_LOG_LEVEL* {.strdefine: "butlerloglevel".}: string = "lvlerror"

const LOG_LEVEL*: Level = parseEnum[Level](BUTLER_LOG_LEVEL)

proc getLoggers*(): seq[Logger] =
  getHandlers()

proc log(logger: Logger, logLevel: static Level, message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= logLevel:
      try:
        logging.log(logger, logLevel, message)
      except Exception as e:
        echo "Logging is triggering errors!", e.repr
        discard

proc log*(loggers: seq[Logger], logLevel: static Level, message: string) {.raises: [].} =
  {.cast(noSideEffect).}:
    when LOG_LEVEL <= logLevel:
      for logger in loggers:
        try:
          logging.log(logger, logLevel, message)
        except Exception as e:
          echo "Logging is triggering errors!", e.repr
          discard

proc log*(logLevel: static Level, message: string) =
  getLoggers().log(logLevel, message)

proc debug*(message: string)  =
  log(lvlDebug, message)

proc notice*(message: string) =
  log(lvlNotice, message)

proc warn*(message: string) =
  log(lvlWarn, message)

proc error*(message: string) =
  log(lvlError, message)

proc fatal*(message: string) =
  log(lvlFatal, message)
