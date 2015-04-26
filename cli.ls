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

#
# Things that I know and can fill in for params that ask.
#

facts = 
  ip: '127.0.0.1'
  info: 'Some info'

module.exports = (server) ->
  server.server.on 'connect' cli_handler
  s = net.createServer (socket) -> cli_open socket
  s.maxConnections = 10;
  s.listen 7002
  console.log "Telnet server on 7002"

module.exports.clic = cli_commands = ^^commands

#
# Quit this CLI session.
#

cli_commands.quit = quit = (socket, cb) ->
  return socket.end!

cli_commands.quit.params =
  * socket: "The socket to close."
  ...

cli_commands.quit.doc = """
Quit your session.
"""

cli_commands.help = (w, command, cb) ->
  if command
    if cli_commands[command]?doc
      pstrings = []
      commstring = ""
      for param in cli_commands[command].params
        unless param.private
          for key, val of param
            continue if key in [\optional \private]
            pstrings.push "  #key: #val"
            key = "[#key]" if param.optional
            commstring += " " + key
      w ""
      w "  #command#commstring"
      w ""
      w that
      for x in pstrings
        w x
      w ""
    else
      w "#command is not known."
  else
    w "Commands available:"
    for command, junk of cli_commands
      if cli_commands[command].doc
        w "  #command -- #that"
  cb!

cli_commands.help.params =
  * w: "Write socket", private: true
  * command: "Command to get help on", optional: true

cli_commands.help.doc = """
Show help.
"""

#
# Fill in the facts if I have them.
#
pre_resolve = (params) ->
  newparams = []
  optionals = 0
  for param in params
    for key, val of param
      if facts[key]
        newparams.push facts[key]
      else
        newparams.push null unless key in [\optional \private]
        optionals++ if param['optional']
  return [optionals, newparams]

#
# Parse a line of input for a command
#

do_parse = (line, rl, socket) ->
  w = (line) -> socket.write "#line\r\n", 'utf8' if typeof line == 'string'
  facts["w"] = w
  facts["socket"] = socket
  [first, ...rest] = line / ' '
  first = shortcuts[first] ? first
  if first == ""
     return rl.prompt!
  cmd = cli_commands[first]
  if cmd?params # There's a command!
    # Fill params in with facts
    [optcount, params] = pre_resolve that
    # Fill in with the rest of what we know.
    pp = [p ? rest.shift! for p in params]
    if rest.length > 0
      w "Too many arguments."
      rl.prompt!
    else if [p for p in pp when p == undefined].length > optcount
      w "Not enough arguments."
      rl.prompt!
    else
      # Add the callback to the end.
      pp.push (err, result) ->
        if err
          w err
        else
          if cmd.returnformatter
            cmd.returnformatter w, result
          else
            w result
        rl.prompt!
      cmd.apply cli_commands, pp
  else
    w "That command is unknown."
    rl.prompt!
  

function cli_open socket
  rl = null
  # Main CLI command processor
  cli = (line) ->
    do_parse line, rl, socket

  # Tell Telnet to not buffer.
  buf = new Buffer [255 253 34 255 250 34 1 0 255 240 255 251 1]
  socket.write buf, 'binary'

  got_options = false # We don't know it's Telnet yet
  option_checker = (data) ->
    if data.readUInt8(0) == 255
      got_options := true
  socket.on 'data', option_checker
  <- setTimeout _, 300 # To allow for option eating
  
  socket.removeListener 'data', option_checker
  rl := readline.createInterface socket, socket, null, got_options
    ..setPrompt '>'
    ..on 'line' cli
    ..output.write '\r                 \r' # Clear options for non-Telnet
    ..prompt!

function cli_handler req, socket, head
  cli_open socket
