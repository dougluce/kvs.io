require! {
  readline
  './commands'
  net
  os
  ipv6
  bunyan
}

log = null

shortcuts = 
  '?': 'help'
  new: 'newbucket'
  nb: 'newbucket'
  sk: 'setkey'
  gk: 'getkey'
  lk: 'listkeys'
  dk: 'delkey'
  db: 'delbucket'

facts = cli_commands = null

#
# Record my own IP addresses.
#

my_ip = []
for dev, addresses of os.networkInterfaces!
  for alias in addresses
    switch alias.family
    case 'IPv6'
      address = new ipv6.v6.Address alias.address
      if address.isLinkLocal!
        continue
      if address.isLoopback!
        continue
      my_ip.push address.address
    case 'IPv4'
      address = new ipv6.v4.Address alias.address
      if address.parsedAddress[0] == '127'
        continue
      my_ip.push address.address

my_ip = my_ip.join ', '

accept_web_connection = (req, socket, head) ->
  if req.url == 'cli'
    facts :=
      info: "Via CONNECT cli request [#{os.hostname!} #my_ip]"
      ip: req.connection.remoteAddress
      fd: socket._handle.fd
    log.info facts
    return cli_open socket
  socket.end!

accept_telnet_connection = (socket) ->
  socket.setNoDelay!
  fd = socket._handle.fd
  socket.on 'end' ->
    log.info {fd: fd}, "lost connection"
  facts :=
    info: "Via Telnet [#{os.hostname!} #my_ip]"
    ip: socket.remoteAddress
    fd: fd
  log.info facts
  cli_open socket

#
# Initialize our commands.  This allows tests to send in different
# command objects.
#

export init = (new_cli_commands = commands) ->
  # Clone it so we don't pollute the upstream object.
  cli_commands := ^^new_cli_commands 
  define_locals!

#
# Start the standalone telnet server.
#

export start_telnetd = (port = 7002) ->
  log := bunyan.getLogger 'cli_telnetd'
  # For telnet version
  telnet_server = net.createServer accept_telnet_connection
  telnet_server.maxConnections = 10;
  telnet_server.listen port
  log.info "Telnet server on #port"
  return telnet_server

#
# Given a Restify http server, listen to the connect event
# so we can get sessions from that.
#

export start_upgrader = (server, tag = "") ->
  log := bunyan.getLogger "cli_upgrader#tag"
  # For Web version
  server.server.on 'connect' accept_web_connection

module.exports.banner = banner = "Welcome to kvs.io.  Type 'help' for help."

#
# Extend the commands object with commands that support
# the CLI.
#

function define_locals
  #
  # Quit this CLI session.
  #
  cli_commands.quit = quit = (w, socket, cb) ->
    w "Disconnecting."
    return socket.end!
  
  cli_commands.quit.params =
    * w: "Write socket", private: true
    * socket: "The socket to close."
  
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
  log.info {fd: socket._handle.fd}, line
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
    ..output.write banner + "\r\n"
    ..prompt!

