import nimibook

var book = initBookWithToc:
  entry("Welcome to ThreadButler!", "index.nim")
  entry("Getting Started", "basics.nim")
  entry("Examples", "examples.nim")
  entry("Integrations", "integrations.nim")
  section("Reference Docs", "reference.nim"):
    entry("Flags", "flags.nim")
    entry("ThreadServer", "threadServer.nim")
    entry("Docs for generated code", "generatedCodeDocs.nim")
    entry("Glossary", "glossary.nim")
  entry("Contributing", "contributing.nim")
nimibookCli(book)
