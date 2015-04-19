require! {
  'basho-riak-client': Riak
  restify
  bunyan
  'bunyan-prettystream': PrettyStream
  readline
  ipware
  net
  './commands'
}

#
# Restify route handlers
#

function create_bucket req, res, next
  (err, bucket_name) <- commands.create_bucket req.headers, ipware!get_ip req
  if err == 'bucket already exists'
     # This should never happen.
     return next new restify.InternalServerError \
       "cannot create bucket #{bucket_name}."
  return next err if err
  res.send 201, bucket_name
  next!

function delbucket req, res, next
  {bucket} = req.params
  err <- commands.delbucket bucket
  return next new restify.NotFoundError "Entry not found." if err == 'not found'
  return next new restify.ForbiddenError "Remove all keys from the bucket first." if err == 'not empty'
  return next err if err
  res.send 204
  next!

function setkey req, res, next
  {bucket, key, value} = req.params
  err <- commands.setkey bucket, key, value
  return next new restify.NotFoundError "No such bucket." if err == 'not found'
  res.send 201
  next!

function getkey req, res, next
  {bucket, key} = req.params
  err, value <- commands.getkey bucket, key
  return next new restify.NotFoundError "Entry not found." if err == 'not found'
  return next err if err
  res.send value
  next!

function delkey req, res, next
  {bucket, key} = req.params
  err <- commands.delkey bucket, key
  return next new restify.NotFoundError "Entry not found." if err == 'not found'
  return next err if err
  res.send 204
  next!

function listkeys req, res, next
  {bucket} = req.params
  err, values <- commands.listkeys bucket
  return next new restify.NotFoundError "Entry not found." if err == 'not found'
  return next err if err
  res.send if res.ct == 'text/plain'
    JSON.stringify(values)
  else
    values
  next!

rh = 0
function contentTypeChecker req, res, next
  res.setHeader 'Server' 'ksv.io' + unless (rh := (rh + 1) % 10) then ' -- try CONNECT for kicks' else ''
  # Favor JSON over text.
  if req.accepts 'text/plain'
    res.ct = 'text/plain'
  if req.accepts 'application/json'
    res.ct = 'application/json'
  next!

cli_setup = (socket) ->
  rl = null
  # Main CLI command processor
  cli = (line) ->
    if line == 'quit'
      return socket.end!
    rl.prompt!

  # Setup code
  buf = new Buffer [255 253 34 255 250 34 1 0 255 240 255 251 1]
  socket.write buf, 'binary'

  got_options = false
  option_checker = (data) ->
    if data.readUInt8(0) == 255
      got_options := true
  socket.on 'data', option_checker
  <- setTimeout _, 1000 # To allow for option eating
  
  socket.removeListener 'data', option_checker
  rl := readline.createInterface socket, socket, null, got_options
    ..setPrompt '>'
    ..on 'line' cli
    ..output.write '\r                 \r' # Clear options
    ..prompt!

function cli_handler req, socket, head
  cli_setup socket

exports.init = (server) ->
  commands.init!
  server.use contentTypeChecker
  server.use restify.bodyParser!

  server.get '/createbucket/' create_bucket
  server.get '/setkey/:bucket/:key/:value' setkey
  server.post '/setkey' setkey
  server.get '/getkey/:bucket/:key' getkey
  server.post '/getkey' getkey
  server.get '/delkey/:bucket/:key' delkey
  server.post '/delkey' delkey
  server.get '/listkeys/:bucket' listkeys
  server.get '/delbucket/:bucket' delbucket
  server.get '/noop' (rq, rs, nx) -> rs.send 200; nx! 
  req, res, route, err <- server.on 'uncaughtException' 
  throw err

prettyStdOut = new PrettyStream!
prettyStdOut.pipe process.stdout

if !module.parent # Run stand-alone
  server = restify.createServer do
    name: 'ksv.io'
  server.server.on 'connect' cli_handler
  server.on 'after' restify.auditLogger do
    * log: bunyan.createLogger(
      * name: 'audit'
        stream: prettyStdOut
        type: 'raw'
      )
  exports.init server
  <- server.listen 8080
  console.log '%s listening at %s', server.name, server.url

  s = net.createServer (socket) -> cli_setup socket
  s.maxConnections = 10;
  s.listen 7002

