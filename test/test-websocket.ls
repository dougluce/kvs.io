require! {
  ws: WebSocket
  chai: {expect}
  sinon
  '../lib/api'
  './utf-cases'
  './utils'
  bunyan
  async
}

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

describe 'Websockets' ->
  actual_buckets = registered_buckets = sandbox = server = client = json_client = ws = null

  ws_setkey = (bucket, done, key = "clubbed", value="into dank submission") ->
    ws.send JSON.stringify do
      command: "setkey"
      bucket: bucket
      key: key
      value: value
    data <- ws.get
    expect JSON.parse(data) .to.eql do
      success: true
    done!

  ws_getkey = (bucket, key, done) ->
    ws.send JSON.stringify do
      command: "getkey"
      bucket: bucket
      key: key
    data <- ws.get
    data = JSON.parse data
    expect data.success .to.be.true
    done data.result

  ws_delbucket = (bucket, done) ->
    ws.send JSON.stringify do
      command: "delbucket"
      bucket: bucket
    data <- ws.get
    expect JSON.parse(data) .to.eql do
      success: true
    done!

  ws_delkey = (bucket, key, done) ->
    ws.send JSON.stringify do
        command: "delkey"
        bucket: bucket
        key: key
    <- ws.get
    done!

  before (done) ->
    logger = bunyan.getLogger 'test-api'  
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      utils.stub_riak_client sandbox
    logstub = sandbox.stub logger
    s, c, j <- utils.startServer
    [server, client, json_client] := [s, c, j]
    api.init server, logstub
    utils.clients!
    a, r <- utils.recordBuckets
    [actual_buckets, registered_buckets] := [a, r]
    messageCallback = null
    ws := new WebSocket "ws://localhost:#{server.address!port}/ws"
      ..on 'open' ->
        done!
    ws.on 'message' (data, flags) ->
      messageCallback data
    ws.get = (cb) ->
        messageCallback := cb

  after (done) ->
    <- utils.checkBuckets actual_buckets, registered_buckets
    ws.close!
    client.close!
    json_client.close!
    <- server.close
    sandbox.restore!
    done!

  describe "/various" ->
    specify 'Deal with syntax errors' (done) ->
      ws.send '{"command" "newbucket"}' # There's no comma there.
      data <- ws.get
      expect JSON.parse(data) .to.eql do
        success: false
        errors:
          "Could not parse command"
          "Unexpected string"
      done!
  
    specify 'Deal with argument mismatch' (done) ->
      ws.send '{"command": "setkey", "key": {"hey": "man"}, "value": "yup"}' # There's no comma there.
      data <- ws.get
      expect JSON.parse(data) .to.eql do
        success: false
        errors:
          "bucket required"
          ...
      done!
  
    specify 'Stringifies JSON values from WS' (done) ->
      ws.send '{"command": "newbucket"}'
      data <- ws.get
      data = JSON.parse data
      bucket = data.result
      expect bucket .to.match /^[0-9a-zA-Z]{20}$/
      expect data.success,'sjvfw' .to.be.true
      ws.send JSON.stringify do
        command: "setkey"
        bucket: bucket
        key: {"hey": "man"}
        value: { "whoa": "what", "takes": "that", "whenever": "man"}
      data <- ws.get
      expect JSON.parse(data),'sjvfw2' .to.eql do
        success: true
      <- ws_delkey bucket, '[object Object]'
      <- ws_delbucket bucket
      done!
  
  describe "/newbucket" ->
    specify 'make a bucket' (done) ->
      ws.send '{"command": "newbucket"}'
      data <- ws.get
      data = JSON.parse data
      expect data.result .to.match /^[0-9a-zA-Z]{20}$/
      expect data.success .to.be.true
      <- ws_delbucket data.result
      done!
      
  describe "/setkey" ->
    specify 'set a key' (done) ->
      ws.send JSON.stringify do
        command: "newbucket"
      data <- ws.get
      data = JSON.parse data
      bucket = data.result
      expect bucket .to.match /^[0-9a-zA-Z]{20}$/
      expect data.success .to.be.true
      ws.send JSON.stringify do
        command: "setkey"
        bucket: bucket
        key: "huh"
        value: "valuewhuh"
      data <- ws.get
      expect JSON.parse(data) .to.eql {success: true}
      <- ws_delkey bucket, "huh"
      <- ws_delbucket bucket
      done!
    
  describe '/keyops' ->
    bucket = ""
    
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!
      
    after (done) ->
      <- ws_delkey bucket, "testbucketinfo"
      ws_delbucket bucket, done

    beforeEach (done) ->
      ws.send JSON.stringify do
        command: "setkey"
        bucket: bucket
        key: "huh"
        value: "dickINTHEparthenon"
      data <- ws.get
      expect JSON.parse(data) .to.eql {success: true}
      done!
  
    specify 'should get a key' (done) ->
      data <- ws_getkey bucket, "huh"
      expect data .to.equal "dickINTHEparthenon"
      <- ws_delkey bucket, "huh"
      done!
  
    specify 'should delete a key' (done) ->
      <- ws_delkey bucket, "huh"
      ws.send JSON.stringify do
        command: "getkey"
        bucket: bucket
        key: "huh"
      data <- ws.get
      data = JSON.parse data
      expect data.success .to.be.false
      expect data.errors .to.eql ['not found']
      done!

  describe '/listkeys' ->
    bucket = ""
    basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string

    keys =
      "the"
      "gods"
      "will"
      "offer"
      "#{basekey}hard"
      "#{basekey}hearts" # Should get lost...
      "#{basekey}"

    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      <- async.eachSeries keys, (key, cb) ->
        ws_setkey bucket, cb, key
      <- ws_setkey bucket
      done!

    after (done) ->
      <- async.eachSeries keys, (key, cb) ->
        key .= substr 0, KEYLENGTH
        ws_delkey bucket, key, cb
      <- ws_delkey bucket, "clubbed"
      <- utils.delete_bucket bucket, '/listkeys'
      done!

    specify 'should list keys' (done) ->
      ws.send JSON.stringify do
        command: "listkeys"
        bucket: bucket
      data <- ws.get
      data = JSON.parse data
      expect data.result .to.have.members do
        * "testbucketinfo"
          "the"
          "gods"
          "will"
          "offer"
          "#{basekey}h"   
          "#{basekey}"
          "clubbed"
      expect data.success .to.be.true
      expect data .to.have.all.keys do
        "result"
        "success"
      done!

  describe 'utf-8' ->
    bucket = ""
  
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!
      
    after (done) ->
      <- utils.delete_bucket bucket, "utf-8"
      done!
      
    utf_case = (tag, utf_string) ->
      specify tag, (done) ->
        <- ws_setkey bucket, _, utf_string, utf_string
        data <- ws_getkey bucket, utf_string
        expect data .to.equal utf_string
        <- utils.delete_key bucket, utf_string, "Utfc"
        done!
  
    #
    # Trim the huge number of UTF cases in development to shorten test
    # runs while still getting some coverage.
    #
    if process.env.NODE_ENV == 'test'
      driver = (case_runner) ->
        for tag, utf_string of utfCases
          utf_case tag, utf_string
    else
      keys = Object.keys utfCases
      for til 10
        key_number = Math.floor(keys.length * Math.random())
        tag = keys.splice(key_number,1)
        utf_string = utfCases[tag]
        utf_case tag, utf_string

  describe '/listen' ->
    bucket = ws2 = ""

    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      # Second socket for "outside" testing.
      ws2 := new WebSocket "ws://localhost:#{server.address!port}/ws"
        ..on 'open' ->
          done!
      messageCallback = null
      ws2.on 'message' (data, flags) ->
        messageCallback data
      ws2.get = (cb) ->
          messageCallback := cb

    after (done) ->
      err <- utils.unmark_bucket bucket
      <- ws_delbucket bucket
      ws2.close!
      done!

    specify "Listen for an event", (done) ->
      do
        <- setTimeout _, 10
        <- ws_setkey bucket, _, "key", "value"
        data <- ws.get
      ws2.send JSON.stringify do
        command: "listen"
        bucket: bucket
      data <- ws2.get
      expect JSON.parse data, 'lfae' .to.eql do
        result:
          bucket: bucket
          event: "setkey"
          args:
            "key"
            "value"
            ""
          data: ""
        success: true
      ws_delkey bucket, "key", done
