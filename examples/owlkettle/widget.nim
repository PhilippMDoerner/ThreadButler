import owlkettle
import threadButler
import threadButler/integration/owlButler
import ./servers
import std/[logging, strformat]

export servers

viewable App:
  server: ChannelHub
  inputText: string
  receivedMessages: seq[string]

proc sendAppMsg(app: AppState) =
  discard app.server.sendMessage(app.inputText.Request)
  app.inputText = ""

method view(app: AppState): Widget =
  result = gui:
    Window:
      defaultSize = (500, 150)
      title = "Client Server Example"

      Box(orient = OrientY, margin = 12, spacing = 6):
        Box(orient = OrientX) {.expand: false.}:
          Entry(placeholder = "Send message to server!", text = app.inputText):
            proc changed(newText: string) =
              app.inputText = newText
            proc activate() =
              app.sendAppMsg()
              
          Button {.expand: false}:
            style = [ButtonSuggested]
            proc clicked() =
              app.sendAppMsg()
              
            Box(orient = OrientX, spacing = 6):
              Label(text = "send") {.vAlign: AlignFill.}
              Icon(name = "mail-unread-symbolic") {.vAlign: AlignFill, hAlign: AlignCenter, expand: false.}
        
        Button():
          Label(text = "Murder")
          proc clicked() =
            IS_RUNNING = false
        
        Separator(margin = Margin(top: 24, bottom: 24, left: 0, right: 0))
        
        Label(text = "Responses from server:", margin = Margin(bottom: 12))
        for msg in app.receivedMessages:
          Label(text = msg) {.hAlign: AlignStart.}

export AppState, App

prepareOwlServers(App)
