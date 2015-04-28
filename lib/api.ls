require! {
  'basho-riak-client': Riak
  restify
  request
  bunyan
  'bunyan-prettystream': PrettyStream
  ipware
  './commands'
  './cli'
  'prelude-ls': {map}
}

log = null

#
# Restify route handlers
#

handle_error = (err, next, good) ->
  errors = 
    'bucket already exists': [restify.InternalServerError, "cannot create bucket."]
    'not found': [restify.NotFoundError, "Entry not found."]
    'not empty': [restify.ForbiddenError, "Remove all keys from the bucket first."]
    'no such bucket': [restify.NotFoundError, "No such bucket."]
  if errors[err]
    return next new that.0 that.1
  return next new restify.InternalServerError err if err # May leak errors externally
  good! # If there's no error, continue on!
  next!

#
# Fill in the facts if I have them.
#
pre_resolve = (params, facts) ->
  newparams = []
  for param in params
    for key, val of param
      if facts[key]
        newparams.push facts[key]
      else
        newparams.push null unless key in [\optional \private]
  return newparams

rh = 0
function contentTypeChecker req, res, next
  res.setHeader 'Server' 'kvs.io' + unless (rh := (rh + 1) % 10) then ' -- try CONNECT for kicks' else ''
  # Favor JSON over text.
  if req.accepts 'text/plain'
    res.ct = 'text/plain'
  if req.accepts 'application/json'
    res.ct = 'application/json'
  next!

makeroutes = (server) ->
  for commandname, command of commands
    httpparams = []
    if command.params
      for param in command.params
        continue if param['private']
        for paramname, doc of param
          httpparams.push paramname
      let ht = httpparams, cm = command
        done = (req, res, next) ->
          facts = req.params with 
            info: req.headers
            ip: ipware!get_ip req
          params = pre_resolve cm.params, facts
          params.push (err, result) ->
            <- handle_error err, next
            res.send cm.success, result
          cm.apply commands, params
        server.get "/#commandname/#{ht.map( (x) -> \: + x ).join '/'}" done
        server.post "/#commandname" done

export init = (server) ->
  server.use contentTypeChecker
  server.use restify.bodyParser!
  server.get /^(|\/|\/index.html|\/w.*)$/ (req, res) ->
    request.get 'http://w.kvs.io/' + req.params[0] .pipe res
  commands.init!
  makeroutes server
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
  server = restify.createServer do
    name: 'kvs.io'
    log: logger
  server.on 'after' restify.auditLogger do
    * log: bunyan.getLogger 'api'
  is_prod = process.env.NODE_ENV == 'production'
  cli server, if is_prod then 23 else 7002
  init server
  <- server.listen if is_prod then 80 else 8080
  console.log '%s listening at %s', server.name, server.url

if !module.parent # Run stand-alone
  standalone!
