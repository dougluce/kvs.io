require! {
  readline
  './commands'
  net
}

/*

Commands to support:

  '/newbucket/' newbucket
  '/setkey/:bucket/:key/:value' setkey
  '/getkey/:bucket/:key' getkey
  '/delkey/:bucket/:key' delkey
  '/listkeys/:bucket' listkeys
  '/delbucket/:bucket' delbucket
  noop
*/

show_help = (socket, cb) ->
  socket.write """
  newbucket\r
  setkey bucket key value\r
  getkey bucket key\r
  delkey bucket key\r
  listkeys bucket\r
  delbucket bucket\r
  noop\r
  """  
  cb!

for own key, val of commands
  if commands[key].params
    console.log "I am #{commands[key].doc}"

pre_resolve = (func) ->
  newobj = {}
  for key, val of func.params
    newobj[key] = switch key
    case 'ip'
      '127.0.0.1'      
    case 'info'
      'This is info'
    default
       ''

do_parse = (line, rl, socket) ->
  w = socket.write
  [first, ...rest] = line / ' '
  switch first
  # These are CLI-only commands.
  case 'quit'
    return socket.end!
  case 'help'
    <- show_help socket
    rl.prompt!
  # These are whatever commands the commands module thinks are
  # commands.
  default
    if commands[first]?params # There's a command!
      params = pre_resolve that
      argcount = Object.keys params .length
      if rest.length != argcount
        w "I'm expecting #argcount arguments to #first"
        rl.prompt!
      else
        cmd = commands[first]
        console.log cmd
        cmd.call '', rest, ->
          w err
          w result
          rl.prompt!
    else
      socket.write "I do not know that one. Sorry.\n"
      rl.prompt!


cli_open = (socket) ->
  rl = null
  # Main CLI command processor
  cli = (line) ->
    do_parse line, rl, socket

  # Setup code
  buf = new Buffer [255 253 34 255 250 34 1 0 255 240 255 251 1]
  socket.write buf, 'binary'

  got_options = false
  option_checker = (data) ->
    if data.readUInt8(0) == 255
      got_options := true
  socket.on 'data', option_checker
  <- setTimeout _, 300 # To allow for option eating
  
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


