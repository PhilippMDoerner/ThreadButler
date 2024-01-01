import chronicles
export chronicles
##[

A simple module handling logging within threadbutler, using std/logging.
The log-level is set at compile-time using the `-d:butlerloglevel=<LogLevelEnumName>` (e.g. `-d:butlerloglevel='lvlAll'`) compiler flag.
Logging at a specific level is compiled in or out based on the log-level allowed at compile-time.

This module is only intended for use within threadButler and for integrations.
]##
