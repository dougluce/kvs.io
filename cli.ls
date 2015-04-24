require! {
  readline
  './commands'
  net
}

shortcuts = 
  '?': 'help'
  new: 'newbucket'
  nb: 'newbucket'
  sk: 'setkey'
  gk: 'getkey'
  lk: 'listkeys'
  dk: 'delkey'
  db: 'delbucket'

show_help = (w, cb) ->
  w "Commands available:\r\n"
  for command, junk of commands
    if commands[command].doc
      w command
      w "   #that"
      w ""
  w """
help\r
   Show this help.\r
quit\r
   Quit your session.\r
"""
  cb!


facts = 
  ip: '127.0.0.1'
  info: 'Some info'

pre_resolve = (params) ->
  newparams = []
  left = 0
  for param in params
    for key, val of param
      if facts[key]
        newparams.push facts[key]
      else
        newparams.push null
        left++

  return [left, newparams]

do_parse = (line, rl, socket) ->
  w = (line) -> socket.write "#line\r\n", 'utf8' if line
  [first, ...rest] = line / ' '
  first = shortcuts[first] ? first
  switch first
  # These are CLI-only commands.
  case 'quit'
    return socket.end!
  case 'help'
    <- show_help w
    rl.prompt!
  # These are whatever commands the commands module thinks are
  # commands.
  default
    if commands[first]?params # There's a command!
      [argcount, params] = pre_resolve that
      if rest.length != argcount
        w "I'm expecting #argcount arguments to #first"
        rl.prompt!
      else
        cmd = commands[first]
        pp = [p ? rest.shift! for p in params]
        pp.push (err, result) ->
          if err
            w err
          else
            if cmd.returnformatter
              w cmd.returnformatter result
            else
              w result            
          rl.prompt!
        cmd.apply commands, pp
    else
      w "That command is unknown."
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


