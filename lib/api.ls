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
}

swagger = 
  * swagger: "2.0"
    info:
      title: "API for kvs.io",
      description: "An API for using the kvs.io key-value store.",
      version: "0.1"
    consumes: ["text/plain; charset=utf-8", "application/json"]
    produces: ["text/plain; charset=utf-8", "application/json"]
    basePath: "/"
    paths: {}

swaggerOperation = (path, cmd) ->
  * operationId: "get#path"
    tags: [path]
    summary: cmd.summary
    description: cmd.description
    parameters: [p for p in cmd.params when not p['x-private']]
    responses:
      default:
        description: "Invalid request."
        schema:
          "$ref": "#/definitions/Error"
      200:
        description: "Successful request."
        schema:
          "$ref": "#/definitions/Weather"
  
errors = 
  'bucket already exists': [restify.InternalServerError, "cannot create bucket."]
  'not found': [restify.NotFoundError, "Entry not found."]
  'not empty': [restify.ForbiddenError, "Remove all keys from the bucket first."]
  'no such bucket': [restify.NotFoundError, "No such bucket."]

handle_error = (err, next, good) ->
  return next new that.0 that.1 if errors[err]
  return next new restify.InternalServerError err if err # May leak errors externally
  good! # If there's no error, continue on!
  next!

rh = 0
function setHeader req, res, next
  res.setHeader 'Server' 'kvs.io' + unless (rh := (rh + 1) % 10) then ' -- try CONNECT for kicks' else ''
  next!

#
# Fill in the facts if I have them.
#
resolve = (params, facts) ->
  newparams = []
  for param in params
    if facts[param['name']]
      newparams.push facts[param['name']]
  if newparams.length != params.length
    return null
  return newparams

makeroutes = (server, logger) ->
  for commandname, command of commands
    if command.params
      httpparams = []
      for param in command.params
        continue if param['x-private']
        httpparams ++= param['name']
      let name = commandname, ht = httpparams, cm = command
        handler = (req, res, next) ->
          facts = req.params with 
            info: req.headers
            ip: ipware!get_ip req
          if process.env.NODE_ENV != 'production'
            facts['test'] = "env #{process.env.NODE_ENV}"
          params = resolve cm.params, facts
          if params == null
            return res.send 400, "params incorrect"
          params.push (err, result) ->
            <- handle_error err, next
            res.send cm.success, result
            params.pop!
            logger.info params, "api: name"
          cm.apply commands, params

        params = ht.map( (x) -> \: + x ).join '/'
        params := '/' + params if params

        docparams = {}
        for parm in cm.params
          docparams[parm.name] = parm
        server.get "/#commandname#params" handler
        swagger.paths[commandname] = 
          * get: swaggerOperation commandname, cm     
            post: swaggerOperation commandname, cm     
        server.post "/#commandname" handler

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

swaggerJson = (req, res) ->
  res.send JSON.stringify swagger

export init = (server, logobj) ->
  logger = logobj
  swagger.host = server.name
  server.use setHeader
  server.use restify.bodyParser!
  server.use restify.CORS!
  server.use restify.fullResponse!

  server.get /^(|\/|\/index.html|\/w.*)$/ web_proxy
  commands.init!
  makeroutes server, logger
  server.get "/swagger.json" swaggerJson

  req, res, route, err <- server.on 'uncaughtException' 
  throw err

if process.env.NODE_ENV == 'production'
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

  process.on 'SIGUSR2' ->
    log.reopenFileStreams!

  log

export standalone = ->
  logger = bunyan.getLogger 'api'
  is_prod = process.env.NODE_ENV == 'production'

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
    
  init server, logger

  <- server.listen if is_prod then 80 else 8080

  cli.start_upgrader server # Allow upgrades to CLI
  logger.info '%s listening at %s', server.name, server.url

  # HTTPS server
  try
    options['key'] = fs.readFileSync '/etc/ssl/kvs.io.key'
    options['certificate'] = fs.readFileSync '/etc/ssl/kvs.io.crt'
  if options['key'] and options['certificate']
    secure_server = restify.createServer options
    secure_server.on 'after' restify.auditLogger do
      * log: bunyan.getLogger 'api'
    init secure_server
    <- secure_server.listen if is_prod then 443 else 8081
    cli.start_upgrader secure_server # Allow upgrades to CLI
    logger.info '%s listening at %s', secure_server.name, secure_server.url

if !module.parent # Run stand-alone
  standalone!

