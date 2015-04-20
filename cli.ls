require! {
  readline
  './commands'
  net
}

cli_open = (socket) ->
  rl = null
  # Main CLI command processor
  cli = (line) ->
    if line == 'quit'
      return socket.end!
    rl.prompt!

  # Setup code
  buf = new Buffer [255 253 34 255 250 34 1 0 255 240 255 251 1]
  socket.write buf, 'binary'

  got_options = false
  option_checker = (data) ->
    if data.readUInt8(0) == 255
      got_options := true
  socket.on 'data', option_checker
  <- setTimeout _, 1000 # To allow for option eating
  
  socket.removeListener 'data', option_checker
  rl := readline.createInterface socket, socket, null, got_options
    ..setPrompt '>'
    ..on 'line' cli
    ..output.write '\r                 \r' # Clear options
    ..prompt!

function cli_handler req, socket, head
  cli_open socket

module.exports = (server) ->
  server.server.on 'connect' cli_handler
  s = net.createServer (socket) -> cli_open socket
  s.maxConnections = 10;
  s.listen 7002
  console.log "Telnet server on 7002"


