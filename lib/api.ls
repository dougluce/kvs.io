require! {
  restify
  request
  bunyan
  'bunyan-prettystream': PrettyStream
  ipware
  './commands'
  './callbacks'
  './cli'
  './websocket': {accept_upgrade}
  fs
  npid
  'media-type'
  contenttype
  path
  'bunyan-logstash'
  './swagger': {swagger, swaggerOperation}
  './common': {errors}
  '../config.json'
}

logger = null

unless process.env.NODE_ENV?
  process.env.NODE_ENV = "development"

config = config[process.env.NODE_ENV]

handle_error = (err, next, good) ->
  return next new that.0 that.1 if errors[err]
  return next new restify.InternalServerError err if err # May leak errors externally
  good! # If there's no error, continue on!
  next!

rh = 0
function setHeader req, res, next
  res.setHeader 'Server' config.hostname + unless (rh := (rh + 1) % 10) then ' -- try CONNECT for kicks' else ''
  next!

#
# Fill in the facts if I have them.
#
resolve = (req, params, facts) ->
  newparams = []
  for param in params
    if facts[param.name]
      newparams.push facts[param.name]
    else if param.in == 'body'
      newparams.push req.body
    else unless param.required
      newparams.push null
  if newparams.length != params.length
    return null
  return newparams

makeHandler = (url, command) ->
  (req, res, next) ->
    params = {} <<<< req.params
    if command.mapparams
      for key in Object.keys command.mapparams
        if params[key]
          params[command.mapparams[key]] = params[key]
          delete params[key]
    facts = params with 
      info: req.headers
      ip: ipware!get_ip req
    params = resolve req, command.params, facts
    unless params
      return res.send 400, "params incorrect"
    # The callback.
    params.push (user, err, result) ->
      <- handle_error err, next
      res.send command.success, result
      params.pop! # Remove callback for reporting.
      logger.info params, "api: name"
    command.apply null, params

makeroutes = (server) ->
  for let commandname, command of commands when command.params
    # The route handler.
    # Simple form.
    getUrl = "/#commandname"
    handler = makeHandler getUrl, command
    for param in command.params
      continue if param['x-private']
      unless param['required']
        server.get getUrl, handler
      getUrl += "/:#{param.name}"
    server.get getUrl, handler
    server.post "/#commandname" handler

    server[that[0]] that[1], handler if command.rest
    swaggerOperation commandname, command

web_proxy = (req, res, next) ->
  res.setHeader 
  options = 
    url: 'http://w.kvs.io' + req.params[0]
    headers: 
      'X-Forwarded-For': ipware!get_ip(req).clientIp
  if req.headers['user-agent']
    options.headers['user-agent'] = req.headers['user-agent']
  if req.headers['referer']
    options.headers['referer'] = req.headers['referer']
  request.get options .pipe res
  next!

#
# This is because the negotiator module will balk if any media type
# parameter (except for q) doesn't explicitly match the server's
# allowed parameters.  And those allowed parameters aren't allowed to
# have parameters specified.
#

cleanAccepts = (req, res, next) ->
  types = []
  if req.headers.accept
    for type in contenttype.splitContentTypes req.headers.accept
      media = mediaType.fromString type
      delete media.parameters.charset
      types.push media.asString!
    req.headers.accept = types.join ', '
  next!

export init = (server, logobj) ->
  logger ?:= logobj
  server.use setHeader
  server.use cleanAccepts
  server.use restify.bodyParser!
  server.use restify.queryParser!
  server.use restify.acceptParser server.acceptable
  server.use restify.CORS!

  commands.init!
  
  makeroutes server
  server.get /^(|\/|\/index.html|\/favicon.ico|\/w\/|\/w|\/w\/.*)$/ web_proxy
  
  host = config.hostname + ':' + server.address!?port
  callbacks.set_listen_port server.address!?port
  server.get "/swagger/resources.json" (req, res) ->
    res.send swagger <<< host: host

  server.pre (req, res, next) ->
    if req.url == '/docs/' 
      req.url := '/docs/index.html'
    next!

  server.get /^\/docs$/ (req, res) -> 
    res.header 'Location' '/docs/'
    res.send 302

  server.get /^\/docs.*/ restify.serveStatic do
    directory: path.join path.resolve __dirname, '..', 'swagger'

  # For callbacks
  server.post '/respond/:listener/:bucket/:pid' callbacks.respond

  server.on 'upgrade', accept_upgrade
  
  req, res, route, err <- server.on 'uncaughtException' 
  throw err

#
# Set up logging.  Supports logstash, files, and stdout (for
# debugging)
#

bunyan.defaultStreams := []

if config.debugStdout
  prettyStdOut = new PrettyStream!
  prettyStdOut.pipe process.stderr
  bunyan.defaultStreams.push do
    * level: 'debug'
      type: 'raw'
      stream: prettyStdOut

if config.logStash
  logStash = bunyanLogstash.createStream do
    * host: config.logStash.host
      port: config.logStash.port
  for level in config.logStash.levels
    bunyan.defaultStreams.push do
      * level: level
        type: 'raw'
        stream: logStash

for logLevel in <[ debug error info ]>
  if config["#{logLevel}Log"]
    bunyan.defaultStreams.push do
      * level: logLevel
        path: config["#{logLevel}Log"]

bunyan.getLogger = (name) ->
  log = if bunyan.defaultStreams
    bunyan.createLogger name: name, streams: bunyan.defaultStreams
  else
    bunyan.createLogger name: name

  process.on 'SIGUSR2' ->
    log.reopenFileStreams!

  log

handle_connect = (req, socket, head) ->
  if req.url == 'cli' # Asked for a CLI connection.
    facts =
      info: "Via CONNECT cli request [#{os.hostname!} #my_ip]"
      ip: req.connection.remoteAddress
      socket: socket
    facts['fd'] = if socket._handle
      socket._handle?fd
    else
      "unknown FD"
    logger.info facts, "connect"
    cli.register_facts socket, facts
    return cli.cli_open socket
  socket.end! # Not a proper connect, give it up.

export standalone = ->
  if config.pidFile
    try
      pid = npid.create config.pidFile, true # Force pid creation
      pid.removeOnExit!
    catch err
      console.log err
      process.exit 1

  logger := bunyan.getLogger 'api'

  if config.stubRiak
    logger.info "Stubbing riak for test"
    require! {
      '../test/utils': {stub_riak_client}
      sinon
    }
    stub_riak_client sinon

  options =
    name: 'kvs.io'
    log: logger

  server = restify.createServer options
    ..on 'after' restify.auditLogger do
      * log: logger

  <- server.listen config.webPort || 80
  init server

  if config.cliPort
    cli.init! # Fire up the CLI system.
    cli.start_telnetd config.cliPort

  server.server.on 'connect' handle_connect

  logger.info '%s listening at %s', server.name, server.url

  # HTTPS server
  if config.spdy
    options.spdy = 
      ciphers: 'ECDHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA256:AES128-GCM-SHA256:HIGH:!MD5:!aNULL'
      honorCipherOrder: true
      cert: fs.readFileSync config.spdy.cert
      key: fs.readFileSync config.spdy.key
      ca: fs.readFileSync config.spdy.ca

    secure_server = restify.createServer options
    secure_server.on 'after' restify.auditLogger do
      * log: bunyan.getLogger 'api'
    init secure_server

    <- secure_server.listen config.spdy.port || 443
    secure_server.server.on 'connect' handle_connect
    logger.info '%s listening at %s', secure_server.name, secure_server.url

if !module.parent # Run stand-alone
  standalone!
