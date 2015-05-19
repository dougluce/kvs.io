require! {
  restify
  request
  bunyan
  'bunyan-prettystream': PrettyStream
  ipware
  './commands'
  './cli'
  'prelude-ls': {map}
  fs
  npid
  'media-type'
  contenttype
}

is_prod = process.env.NODE_ENV == 'production'

errors = 
  'bucket already exists': [restify.InternalServerError, "cannot create bucket."]
  'not found': [restify.NotFoundError, "Entry not found."]
  'not empty': [restify.ForbiddenError, "Remove all keys from the bucket first."]

handle_error = (err, next, good) ->
  return next new that.0 that.1 if errors[err]
  return next new restify.InternalServerError err if err # May leak errors externally
  good! # If there's no error, continue on!
  next!
  
swagger = 
  * swagger: "2.0"
    info:
      title: "The kvs.io API",
      description: """
# A simple, fast, always-available key-value store.

The kvs.io service provides a globally accessible key-value store
organized into buckets and stored redundantly.

This service lets you store data securely using only browser-based
HTML without the need for any complex set-up.

The first principle of kvs.io is simplicity. The regular API gives you
all the semantic power of REST. The simple API lets you stuff
parameters into the URL for a normal HTTP GET or send them as form
data with a POST.  All calls may be made via HTTP or HTTPS (use of
HTTPS is STRONGLY recommended).

The second principle of kvs.io is reliability.  Redundant front-ends
keep availability high.  Each key-value pair is stored on at least
three separate back-end servers.

The third princple of kvs.io is speed.  A single, simple REST
transaction is all it takes.  Your bucket name is your key to the
system, and there is no need to go through an authentication
transaction.  One hit in, one response out.  SPDY is supported.

""",
      version: "0.1"
    consumes: ["text/plain; charset=utf-8", "application/json"]
    produces: ["text/plain; charset=utf-8", "application/json"]
    basePath: "/"
    paths: {}


# Template for a single operation.
#
# Encompasses both REST and simple forms.
#
# Simple form is all URL based

swaggerOperation = (commandname, cmd) ->
  path = commandname
  restPath = []
  getParams = []
  postParams = []
  restParams = []
  for param in cmd.params
    continue if param['x-private']
    path += "/{#{param.name}}"
    restPath.push "{#{param.name}}" if param.required and param.in != 'body'
    getParams.push ({} <<<< param) <<< do
      in: 'query'
      type: 'string'
    postParams.push ({} <<<< param) <<< do
      in: 'formData'
      type: 'string'
    restParams.push ({} <<<< param) <<< do
      in: if param.in then param.in else if param.required then 'path' else 'query'
      type: 'string'
  operation = 
    * summary: cmd.summary
      description: cmd.description
      responses:
        "#{cmd.success}":
          description: "Successful request."
        500:
          description: "Internal server error."

  for error in cmd.errors
    operation.responses <<<
       "#{new errors[error][0]!statusCode}":
         description: errors[error][1]

  getOp = ({} <<<< operation) <<<
    tags: [cmd.group, \simple]
    operationId: "get#commandname"
  getOp.parameters = getParams if getParams.length > 0

  postOp = ({} <<<< operation) <<<
    tags: [cmd.group, \simple]
    operationId: "post#commandname"
  postOp.parameters = postParams if postParams.length > 0

  swagger.paths.{}"/#path".get = getOp
  swagger.paths.{}"/#commandname".post = postOp

  if cmd.rest
    restOp = ({} <<<< operation) <<<
      tags: [cmd.group, \rest]
      operationId: "rest#commandname"
    restOp.parameters = restParams if restParams.length > 0
    restPath = '/' + restPath.join '/'
    method = cmd.rest[0]
    method = 'delete' if method == 'del'
    swagger.paths.{}"#restPath".[method] = restOp

rh = 0
function setHeader req, res, next
  res.setHeader 'Server' 'kvs.io' + unless (rh := (rh + 1) % 10) then ' -- try CONNECT for kicks' else ''
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

# exported for testing purposes.
export additional_facts = ->
  facts = {}
  unless is_prod
    facts['test'] = "env #{process.env.NODE_ENV}"
  facts

makeroutes = (server, logger) ->
  for let commandname, command of commands when command.params
    # The route handler.
    handler = (req, res, next) ->
      params = {} <<<< req.params
      if command.mapparams
        for key in Object.keys command.mapparams
          if params[key]
            params[command.mapparams[key]] = params[key]
            delete params[key]
      facts = params with 
        info: req.headers
        ip: ipware!get_ip req
      facts <<< exports.additional_facts!
      params = resolve req, command.params, facts
      unless params
        return res.send 400, "params incorrect"
      # The callback.
      params.push (err, result) ->
        <- handle_error err, next
        res.send command.success, result
        params.pop! # Remove callback for reporting.
        logger.info params, "api: name"
      command.apply commands, params

    # Simple form.
    getUrl = "/#commandname"
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
    for type in contenttype.splitContentTypes req.headers.accept
      media = mediaType.fromString type
      delete media.parameters.charset
      types.push media.asString!
    req.headers.accept = types.join ', '
    next!

export init = (server, logobj) ->
  logger = logobj
  server.use setHeader
  server.use cleanAccepts
  server.use restify.bodyParser!
  server.use restify.queryParser!
  server.use restify.acceptParser server.acceptable
  server.use restify.CORS!
  commands.init!
  makeroutes server, logger
  server.get /^(|\/|\/index.html|\/favicon.ico|\/w.*)$/ web_proxy
  host = 'kvs.io'
  unless is_prod
    if server.address!?port
      host = 'localhost:' + that
  server.get "/swagger/resources.json" (req, res) ->
    res.send swagger <<< host: host
  server.get /^\/docs.*/ restify.serveStatic directory: './swagger'
  req, res, route, err <- server.on 'uncaughtException' 
  throw err

if is_prod
  logpath = "#{process.env.HOME}/logs"
  bunyan.defaultStreams :=
    * level: 'error',
      path: "#logpath/kvsio-error.log"
    * level: 'info',
      path: "#logpath/kvsio-access.log"
else
  prettyStdOut = new PrettyStream!
  prettyStdOut.pipe process.stderr
  bunyan.defaultStreams :=
    * level: 'debug',
      path: "/tmp/kvsio-debug.log"
    * level: 'debug',
      type: 'raw'
      stream: prettyStdOut
    
bunyan.getLogger = (name) ->
  log = if bunyan.defaultStreams
    bunyan.createLogger name: name, streams: bunyan.defaultStreams
  else
    bunyan.createLogger name: name

  if is_prod
    process.on 'SIGUSR2' ->
      log.reopenFileStreams!

  log

export standalone = ->
  logger = bunyan.getLogger 'api'

  if is_prod
    try
      pid = npid.create '/var/run/kvsio/kvsio.pid', true # Force pid creation
      pid.removeOnExit!
    catch err
      console.log err
      process.exit 1

  cli.init! # Fire up the CLI system.
  cli.start_telnetd process.env.TELNET_PORT || if is_prod then 23 else 7002

  options =
    name: 'kvs.io'
    log: logger

  server = restify.createServer options
    ..on 'after' restify.auditLogger do
      * log: logger

  if process.env.NODE_ENV not in ['production', 'test']
    logger.info "NOT PROD OR TEST -- RUNNING IN FAKE RIAK MODE"
    require! {
      '../test/utils': {stub_riak_client}
      sinon
    }
    stub_riak_client sinon

  <- server.listen if is_prod then 80 else 8080
  init server, logger

  cli.start_upgrader server # Allow upgrades to CLI
  logger.info '%s listening at %s', server.name, server.url

  # HTTPS server
  options <<<
    spdy:
      cert: fs.readFileSync '/etc/ssl/kvs.io.crt'
      key: fs.readFileSync '/etc/ssl/kvs.io.key'
      ca: fs.readFileSync '/etc/ssl/kvs.io.crt'

  if options['spdy']
    secure_server = restify.createServer options
    secure_server.on 'after' restify.auditLogger do
      * log: bunyan.getLogger 'api'
    init secure_server
    <- secure_server.listen if is_prod then 443 else 8081
    cli.start_upgrader secure_server # Allow upgrades to CLI
    logger.info '%s listening at %s', secure_server.name, secure_server.url

if !module.parent # Run stand-alone
  standalone!

unless process.env.NODE_ENV?
  process.stderr.write "NODE_ENV needs to be set\n"
  process.exit 1
