require! {
  readline
  './commands'
  net
  os
  ipv6
  bunyan
}

logger = null

is_prod = process.env.NODE_ENV == 'production'

shortcuts = 
  '?': 'help'
  new: 'newbucket'
  nb: 'newbucket'
  sk: 'setkey'
  gk: 'getkey'
  lk: 'listkeys'
  dk: 'delkey'
  db: 'delbucket'
  admin: 'root'

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

my_ip := my_ip.join ', '

accept_web_connection = (req, socket, head) ->
  if req.url == 'cli'
    facts :=
      info: "Via CONNECT cli request [#{os.hostname!} #my_ip]"
      ip: req.connection.remoteAddress
    facts['fd'] = if socket._handle
      socket._handle.fd
    else
      "unknown FD"
    unless is_prod
      facts['test'] = "env #{process.env.NODE_ENV}"
    logger.info facts, "connect"
    return cli_open socket
  socket.end!

accept_telnet_connection = (socket) ->
  socket.setNoDelay!
  fd = socket._handle.fd
  socket.on 'end' ->
    logger.info {fd: fd}, "lost connection"
  facts :=
    info: "Via Telnet [#{os.hostname!} #my_ip]"
    ip: socket.remoteAddress
    fd: fd
  unless is_prod
    facts['test'] = "env #{process.env.NODE_ENV}"
  logger.info facts, "connect"
  cli_open socket

#
# Initialize our commands.  This allows tests to send in different
# command objects.
#

export init = (new_cli_commands = commands) ->
  logger := bunyan.getLogger "cli"
  # Clone it so we don't pollute the upstream object.
  cli_commands := ^^new_cli_commands 
  define_locals!

#
# Start the standalone telnet server.
#

export start_telnetd = (port = 7002) ->
  # For telnet version
  telnet_server = net.createServer accept_telnet_connection
  telnet_server.maxConnections = 10;
  telnet_server.listen port
  logger.info "Telnet server started on #port"
  return telnet_server

#
# Given a Restify http server, listen to the connect event
# so we can get sessions from that.
#

export start_upgrader = (server) ->
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
  cli_commands.quit = (w, socket, cb) ->
    w "Disconnecting."
    return socket.end!
  
  cli_commands.quit.params =
    * name: 'w'
      description: "Write socket"
      required: true
      'x-private': true
    * name: 'socket'
      description: "The socket to close."
      required: true
      'x-private': true

  cli_commands.quit.summary = """
  Quit your session.
  """
  
  cli_commands.help = (w, command, cb) ->
    if not command
      w "Commands available:"
      for command of cli_commands
        if cli_commands[command].summary
          w "  #command -- #that"
      return cb!

    if cli_commands[command]?summary
      pstrings = []
      commstring = ""
      for param in cli_commands[command].params
        continue if param['x-private']
        p = param.name
        pstrings.push "  #p: #{param.description}"
        p = "[#p]" if not param.required
        commstring += " " + p
      w ""
      w "  #command#commstring"
      w ""
      w that
      for x in pstrings
        w x
      w ""
      cb!
    else
      w "#command is not known."
      cb!
  
  cli_commands.help.params =
    * name: 'w'
      description: "Write socket"
      'x-private': true
      required: true
    * name: 'command'
      description: "Command to get help on"
      required: false
  
  cli_commands.help.summary = """
  Show help.
  """

  #
  # Playing with idiots.
  #
  cli_commands.root = (rl, cb) ->
    rl.setPrompt '# '
    cb!

  cli_commands.root.params =
    * name: 'rl'
      description: "Readline object"
      'x-private': true
      required: true
    ...

  cli_commands.sh = (rl, cb) ->
    rl.setPrompt '$ '
    cb!

  cli_commands.sh.params =
    * name: 'rl'
      description: "Readline object"
      'x-private': true
      required: true
    ...

  #
  # More playing with idiots.
  #
  cli_commands.echo = (socket, rest, cb) ->
    end = "\r\n"
    if '-n' in rest
      end = ""
    rest = [r.replace(/\\/g, '') for r in rest when r.charAt(0) != '-']
    line = rest.join(' ')
    socket.write "#line#end", 'utf8'
    cb!

  cli_commands.echo.variable = true
  cli_commands.echo.params =
    * name: 'socket'
      description: "Write socket"
      'x-private': true
      required: true
    ...

#
# Fill in the facts if I have them.
#
pre_resolve = (params) ->
  newparams = []
  optionals = 0
  for param in params
    newparams.push facts[param['name']]
    optionals++ if not param['required']
  return [optionals, newparams]

#
# Parse a line of input for a command
#

do_parse = (line, rl, socket) ->
  logger.info {fd: socket._handle.fd}, "cli: #line"
  w = (line) -> socket.write "#line\r\n", 'utf8' if typeof line == 'string'
  facts["w"] = w
  facts["socket"] = socket
  facts["rl"] = rl
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
    if rest.length > 0 and not cmd.variable
        w "Too many arguments."
        return rl.prompt!
    pp.push rest if cmd.variable
    if [p for p in pp when p == undefined].length > optcount
      w "Not enough arguments."
      return rl.prompt!
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
  <- setTimeout _, is_prod ? 200 : 50 # To allow for drainage
  buf = new Buffer [255 253 34 255 250 34 1 0 255 240 255 251 1]
  socket.write buf, 'binary'

  got_options = false # We don't know it's Telnet yet
  option_checker = (data) ->
    if data.readUInt8(0) == 255
      got_options := true
  socket.on 'data', option_checker
  <- setTimeout _, is_prod ? 200 : 1 # To allow for option eating
  
  socket.removeListener 'data', option_checker
  rl := readline.createInterface socket, socket, null, got_options
    ..setPrompt '>'
    ..on 'line' cli
    ..output.write '\r                 \r' # Clear options for non-Telnet
    ..output.write banner + "\r\n"
    ..prompt!

