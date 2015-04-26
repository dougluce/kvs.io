require! {
  chai: {expect}
  restify
  'basho-riak-client': Riak
  '../cli'
  '../commands'
  './utils'
  sinon
  domain
  net
}

class Connector
  buffer = ''
  count = 0
  cb = client = null
  
  (host, port, connect_cb) ->
    client := net.connect port, '127.0.0.1', ->
      connect_cb client
    client.on 'data', (data) ->
      buffer += data.toString!
      lines = buffer.split /\r\n/
      if lines.length >= count
        buffer := ''
        cb lines.splice 0, count

  end: ->
    client.end!

  wait_end: (cb) ->
    client.on 'end' cb

  wait: (new_count, new_cb) ->
    cb := new_cb
    count := new_count

  send: (data, new_count, new_cb) ->
    cb := new_cb
    count := new_count
    client.write data + "\r"

describe "CLI alone" ->
  d = sandbox = server = telnet_server = null

  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      sandbox.stub Riak, "Client", ->
        utils.stub_riak_client

    server := restify.createServer!
    telnet_server := cli server, 7008,  {} # CLI-only commands.
    runServer = ->
      <- server.listen 8089
      console.log '[CLI] %s server listening at %s', server.name, server.url
      utils.clients!
      done!
    domain.create!
      ..on 'error' (err) ->
        if /EADDRINUSE/ == err
          <- setTimeout _, 100
          console.log "Re-running on #err"
          return runServer!
        else
          throw err
      ..run runServer
  
  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    <- utils.after_all
    <- server.close
    <- telnet_server.close
    sandbox.restore!
    done!

  beforeEach (done) ->
    d := new Connector '127.0.0.1', 7008, ->
      data <- d.wait 1 # Wait for telnet options
      x = new Buffer data[0] .toString 'base64'
      expect x, 'be_telnet' .to.eql '77+977+9Iu+/ve+/vSIBAO+/ve+/ve+/ve+/vQE='
      <- setTimeout _, 300  # Because network sucks.
      data <- d.wait 1 # After pause, get option erase string
      expect data .to.eql ['\r                 \r>']
      data <- d.send '', 1 # Enter gives prompt back.
      expect data .to.eql ['>']
      done!

  afterEach (done) ->
    d.wait_end ->
      done!
    data <- d.send 'quit', 1
    expect data .to.eql ['Disconnecting.']

  specify 'help should give me help' (done) ->
    data <- d.send 'help', 4
    expect data, 'hsgmh' .to.eql do
      * 'Commands available:'
        '  quit -- Quit your session.'
        '  help -- Show help.'
        '>'
    done!
    
  specify 'help help should give me help on help' (done) ->
    data <- d.send 'help help', 4
    expect data, 'hhsgmhoh'  .to.eql do
      * ''
        '  help [command]'
        ''
        'Show help.'
    done!

  specify 'Junk command gives me error' (done) ->
    data <- d.send 'GOOBADEE', 2
    expect data .to.eql ['That command is unknown.', '>']
    done!

describe "CLI full commands" ->
  d = server = telnet_server = null

  before (done) ->
    server := restify.createServer!
    commands.init!
    telnet_server := cli server, 7009 # CLI-only commands.
    runServer = ->
      <- server.listen 8089
      console.log '[CLI] %s server listening at %s', server.name, server.url
      utils.clients!
      done!
    domain.create!
      ..on 'error' (err) ->
        if /EADDRINUSE/ == err
          <- setTimeout _, 100
          console.log "Re-running on #err"
          return runServer!
        else
          throw err
      ..run runServer
  
  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    <- server.close
    <- telnet_server.close
    done!

  beforeEach (done) ->
    d := new Connector '127.0.0.1', 7009, ->
      data <- d.wait 1 # Wait for telnet options
      x = new Buffer data[0] .toString 'base64'
      expect x .to.eql '77+977+9Iu+/ve+/vSIBAO+/ve+/ve+/ve+/vQE='
      data <- d.wait 1 # After pause, get option erase string
      expect data .to.eql ['\r                 \r>']
      data <- d.send '', 1 # Enter gives prompt back.
      expect data .to.eql ['>']
      done!

  afterEach (done) ->
    d.wait_end ->
      done!
    data <- d.send 'quit', 1
    expect data .to.eql ['Disconnecting.']

  specify 'help should give me another command' (done) ->
    data <- d.send 'help', 4
    expect data[3], 'hsgmac' .to.not.equal '>'
    done!
    
  specify 'newbucket should create a bucket -- and show me info' (done) ->
    data <- d.send 'newbucket', 2
    expect data[0] .to.match /^Your new bucket is [0-9a-zA-Z]{20}$/
    expect data[1] .to.equal '>'
    bucket = data[0].slice(-20)
    err, result <- utils.bucket_metadata bucket
    expect result.ip .to.equal '127.0.0.1'
    expect result.info .to.match /^Via Telnet [\S+ [0-9\.]+$/
    expect result.date .to.match /^\d{4|-\d\d-\d\dT\d\d:\d\d:\d\d.\d\d\dZ$/
    done!
