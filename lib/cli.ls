require! {
  readline
  './commands'
  net
  os
  ipv6
  bunyan
  '../config.json'
}

logger = null

unless process.env.NODE_ENV?
  process.env.NODE_ENV = "production"

config = config[process.env.NODE_ENV]

# In-memory per-socket information

socket_facts = {}

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

cli_commands = null

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

export start_telnetd = (port) ->
  # For telnet version
  telnet_server = net.createServer accept_telnet_connection
  telnet_server.maxConnections = 20
  telnet_server.listen port, ->
    logger.info "Telnet server started on #{telnet_server.address!port}"
    telnet_server.on 'connection', (conn) -> # For testing
      @last_conn = conn
  return telnet_server

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
    socket.on 'close', cb
    socket.end!
  
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
  # For testing
  #
  cli_commands.sleep = (socket, duration, cb) ->
     if !isNaN duration && 
        parseInt Number duration == duration && 
        !isNaN parseInt duration, 10
        <- setTimeout _, duration * 1000
        cb!
     else
       socket.write "Bad syntax"
       cb!

  cli_commands.sleep.params =
    * name: 'socket'
      description: "Write socket"
      'x-private': true
      required: true
    * name: 'duration'
      description: "Duration of sleep, in seconds."
      required: true

  cli_commands.sleep.summary = """
  Sleep for the given number of seconds.
  """

#
# Fill in the facts if I have them.
#
pre_resolve = (socket, params) ->
  fd = socket._handle?fd
  newparams = []
  optionals = 0
  for param in params
    newparams.push socket_facts[fd][param['name']]
    optionals++ if not param['required']
  return [optionals, newparams]

export register_facts = (socket, facts) ->
  fd = socket._handle?fd
  socket_facts[fd] = facts
  
#
# Parse a line of input for a command
#

do_parse = (line, rl, socket, cb) ->
  fd = socket._handle?fd
  logger.info {fd: fd}, "cli: #line"
  [first, ...rest] = line / ' '
  first = shortcuts[first] ? first
  if first == ""
     return rl.prompt!
  cmd = cli_commands[first]
  w = socket_facts[fd].w

  if cmd?params # There's a command!
    # Fill params in with facts
    [optcount, params] = pre_resolve socket, that
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
    pp.push (user, err, result) ->
      if err
        w err
      else
        if cmd.returnformatter
          cmd.returnformatter w, result
        else
          w result
      rl.prompt!
      cb!
    cmd.apply cli_commands, pp
  else
    w "That command is unknown."
    rl.prompt!
  
export cli_open = (socket) ->
  rl = null
  fd = socket._handle?fd

  socket.on 'end' ->
    logger.info {fd: fd}, "lost connection (end)"
    delete socket_facts[fd]
    socket.destroy!
  socket.on 'close' ->
    logger.info {fd: fd}, "lost connection (close)"
  socket.on 'error' ->
    logger.info {fd: fd}, "connection error"

  # Main CLI command processor
  cli = (line) ->
    rl.pause!
    <- do_parse line, rl, socket
    rl.resume!

  rl := readline.createInterface socket, socket, null
    ..setPrompt '>'
    ..on 'line' cli
    ..output.write banner + "\r\n"
    ..prompt!

  w = (line) -> socket.write "#line\r\n", 'utf8' if typeof line == 'string'
  socket_facts[fd].w = w

accept_telnet_connection = (socket) ->
  socket.setNoDelay!
  facts =
    info: "Via Telnet [#{os.hostname!} #my_ip]"
    ip: socket.remoteAddress
    fd: socket._handle?fd
  if config.logEnv
    facts['test'] = "env #{process.env.NODE_ENV}"
    
  logger.info {} <<< facts, "connect"
  facts['socket'] = socket
  register_facts socket, facts
  cli_open socket
