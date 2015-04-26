require! {
  chai: {expect}
  restify
  './utf-cases'
  '../cli'
  domain
  net
}

class Connector
  buffer = ''
  count = 0
  cb = client = null
  
  (host, port, connect_cb) ->
    client := net.connect 7002, '127.0.0.1', ->
      connect_cb!
    client.on 'data', (data) ->
      buffer += data.toString!
      lines = buffer.split /\r\n/
      if lines.length >= count
        buffer := ''
        cb lines.splice 0, count
  
  wait: (new_count, new_cb) ->
    cb := new_cb
    count := new_count

  send: (data, new_count, new_cb) ->
    cb := new_cb
    count := new_count
    client.write data + "\r"

describe "CLI" ->
  server = null

  before (done) ->
    server := restify.createServer!
    cli server, {} # CLI-only commands.
    runServer = ->
      <- server.listen 8089
      console.log '[CLI] %s server listening at %s', server.name, server.url
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
    done!
  
  describe '/help' ->
    specify 'should give me help' (done) ->
      <- setTimeout _, 500
      d = new Connector '127.0.0.1', 7002, ->
        data <- d.wait 1 # Wait for telnet options
        x = new Buffer data[0] .toString 'base64'
        expect x .to.equal '77+977+9Iu+/ve+/vSIBAO+/ve+/ve+/ve+/vQE='
        data <- d.wait 1 # After pause, get option erase string
        expect data[0] .to.equal '\r                 \r>'
        data <- d.send '', 1 # Enter gives prompt back.
        expect data[0] .to.equal '>'
        data <- d.send 'help', 4
        console.log data
        expect data[0] .to.equal 'Commands available:'
        done!

