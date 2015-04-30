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
}

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
    for key, val of param
      if facts[key]
        newparams.push facts[key]
  if newparams.length != params.length
    return null
  return newparams

makeroutes = (server, logger) ->
  for commandname, command of commands
    if command.params
      httpparams = []
      for param in command.params
        continue if param['private']
        httpparams ++= Object.keys param
      let name = commandname, ht = httpparams, cm = command
        handler = (req, res, next) ->
          facts = req.params with 
            info: req.headers
            ip: ipware!get_ip req
          params = resolve cm.params, facts
          if params == null
            return res.send 400, "params incorrect"
          params.push (err, result) ->
            <- handle_error err, next
            res.send cm.success, result
            params.pop!
            logger.info params, name
          cm.apply commands, params

        server.get "/#commandname/#{ht.map( (x) -> \: + x ).join '/'}" handler
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

export init = (server, logobj) ->
  logger = logobj
  server.use setHeader
  server.use restify.bodyParser!
  server.get /^(|\/|\/index.html|\/w.*)$/ web_proxy
  commands.init!
  makeroutes server, logger
  req, res, route, err <- server.on 'uncaughtException' 
  throw err

prettyStdOut = new PrettyStream!
prettyStdOut.pipe process.stderr

logpath = "/tmp"

if process.env.NODE_ENV == 'production'
  logpath = "#{process.env.HOME}/logs"

bunyan.defaultStreams = 
  * level: 'info',
    type: 'raw'
    stream: prettyStdOut
  * level: 'info',
    path: "#logpath/kvsio-access.log"
  * level: 'error',
    path: "#logpath/kvsio-error.log"

bunyan.getLogger = (name) ->
  if bunyan.defaultStreams
    bunyan.createLogger name: name, streams: bunyan.defaultStreams
  else
    bunyan.createLogger name: name

export standalone = ->
  logger = bunyan.getLogger 'api'
  is_prod = process.env.NODE_ENV == 'production'

  cli.init! # Fire up the CLI system.
  cli.start_telnetd if is_prod then 23 else 7002

  options =
    name: 'kvs.io'
    log: logger

  server = restify.createServer options
  server.on 'after' restify.auditLogger do
    * log: bunyan.getLogger 'api'

  unless is_prod # So we can manually test
    console.log "NOT PRODUCTION -- RUNNING IN FAKE RIAK MODE"
    require! {
      '../test/utils': {stub_riak_client}
      sinon
    }
    stub_riak_client sinon
    
  init server, logger
  <- server.listen if is_prod then 80 else 8080
  cli.start_upgrader server # Allow upgrades to CLI
  console.log '%s listening at %s', server.name, server.url

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
    console.log '%s listening at %s', secure_server.name, secure_server.url

if !module.parent # Run stand-alone
  standalone!
