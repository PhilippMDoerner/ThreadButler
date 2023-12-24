import threadButler
import threadButler/channelHub
import threading/channels
import std/[logging, options, times, tables, strformat, os, sequtils]

const CLIENT_THREAD_NAME = "client"
const SERVER_THREAD_NAME = "backend"
const MESSAGE_COUNT = 100_000
const SEQ_SIZE = 1000

type SmallMessage = distinct string
type LargeMessage = object
  lotsOfNumbers: seq[int]
  sets: set[0..SEQ_SIZE] = {0..SEQ_SIZE}
type SmallResponse = distinct SmallMessage
type LargeResponse = distinct LargeMessage
type SmallRequest = distinct SmallMessage
type LargeRequest = distinct LargeMessage

var smallReceivedCounter = 0
var largeReceivedCounter = 0
var smallSendCounter = 0
var largeSendCounter = 0
var smallFailCounter = 0
var largeFailCounter = 0

threadServer(CLIENT_THREAD_NAME):
  messageTypes:
    SmallResponse
    LargeResponse
  
  handlers:
    proc handleSmallResponse(msg: sink SmallResponse, hub: ChannelHub) =
      smallReceivedCounter.inc

    proc handleLargeResponse(msg: sink LargeResponse, hub: ChannelHub) =
      largeReceivedCounter.inc
  
threadServer(SERVER_THREAD_NAME):
  messageTypes:
    SmallRequest
    LargeRequest
  
  handlers:
    proc handleSmallRequest(msg: sink SmallRequest, hub: ChannelHub) =
      discard hub.sendMessage(msg.SmallResponse)
    
    proc handleLargeRequest(msg: sink LargeRequest, hub: ChannelHub) =
      let resp = LargeResponse(msg)
      let success = hub.sendMessage(resp)
      if not success:
        echo "Failed sending large message"

prepareServers()

    
proc main() =
  let hub = new(ChannelHub, capacity = MESSAGE_COUNT * 2)
  
  let exampleSmall = "A small and short string".SmallRequest
  let exampleLarge = LargeMessage(lotsOfNumbers: (0..SEQ_SIZE).toSeq()).LargeRequest

  hub.withServer(SERVER_THREAD_NAME):
    while IS_RUNNING:
      var t0 = cpuTime()
      for _ in 1..MESSAGE_COUNT:
        smallSendCounter.inc
        let success = hub.sendMessage(exampleSmall)
        if not success:
          smallFailCounter.inc
      
      var counter = 0
      while counter < MESSAGE_COUNT:
        let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
        if response.isSome():
          routeMessage(response.get(), hub)
          counter.inc
      var t1 = cpuTime()
      echo "\nCPU time for small Messages (in s): ", t1 - t0
      echo "SmallMessages: Sent: ", smallSendCounter, " - Received: ", smallReceivedCounter, " - Failed: ", smallFailCounter
      
      var t2 = cpuTime()
      for _ in 1..MESSAGE_COUNT:
        largeSendCounter.inc
        let success = hub.sendMessage(exampleLarge)
        if not success:
          largeFailCounter.inc
      
      counter = 0
      while counter < MESSAGE_COUNT:
        let response: Option[ClientMessage] = hub.readMsg(ClientMessage)
        if response.isSome():
          routeMessage(response.get(), hub)
          counter.inc
      var t3 = cpuTime()

      echo "\nCPU time for Large Messages (in s): ", t3 - t2
      echo "LargeMessages: Sent: ", largeSendCounter, " - Received: ", largeReceivedCounter, " - Failed: ", largeFailCounter
main()