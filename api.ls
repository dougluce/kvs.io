require! {
  'basho-riak-client': Riak
  restify
  bunyan
  'bunyan-prettystream': PrettyStream
  readline
  crypto
  ipware
  net
}

MAXKEYLENGTH = 256
MAXVALUELENGTH = 65536

#
# Here to allow stubbing by tests.
#

riak_client = null

fetchValue = (bucket, key, next) ->
  key .= substr 0, MAXKEYLENGTH
  riak_client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    next

storeValue = (bucket, key, value, next) ->
  key .= substr 0, MAXKEYLENGTH
  err, result <- riak_client.storeValue do
    * bucket: bucket
      key: key
      value: value
  next err if err
  next!

function create_bucket req, res, next
  ex, buf <- crypto.randomBytes 15
  throw ex if ex
  # URL- and hostname-safe strings.
  bucket_name = buf.toString 'base64' .replace /\+/g, '0' .replace /\//g, '1'
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket_name
  return next err if err
  if not result.isNotFound
     # This should never happen.
     return next new restify.InternalServerError \
       "Error, cannot create bucket #{bucket_name}."
  # Mark this bucket as taken and record by whom.
  value =
    ip: ipware!get_ip req
    date: new Date!toISOString!
    headers: req.headers
  # Store headers.
  <- storeValue "buckets", bucket_name, value
  res.send 201, bucket_name
  next!

function delbucket req, res, next
  {bucket} = req.params
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return next err if err
  if result.isNotFound
     return next new restify.NotFoundError "Entry not found."
  # Is there anything in the bucket?
  err, result <- riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
  return next err if err
  if result.values.length > 0
    return next new restify.ForbiddenError "Remove all keys from the bucket first."
  # Nope, delete it.
  err, result <- riak_client.deleteValue do
    * bucket: 'buckets'
      key: bucket
  return next err if err
  if not result
    return next new restify.NotFoundError "Entry not found."
  res.send 204
  next!

function setkey req, res, next
  {bucket, key, value} = req.params
  value .= substr 0, MAXVALUELENGTH

  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return next err if err
  if result.isNotFound
     return next new restify.NotFoundError "No such bucket."
  <- storeValue bucket, key, with new Riak.Commands.KV.RiakObject!
    ..setContentType 'text/plain'
    ..setValue value
  res.send 201
  next!

function getkey req, res, next
  {bucket, key} = req.params
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return next err if err
  if result.isNotFound
     return next new restify.NotFoundError "Entry not found."
  err, result <- fetchValue bucket, key
  return next err if err
  if result.isNotFound
    return next new restify.NotFoundError "Entry not found."
  res.send result.values.shift!value.toString 'utf8'
  next!

function delkey req, res, next
  {bucket, key} = req.params
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return next err if err
  if result.isNotFound
     return next new restify.NotFoundError "Entry not found."
  # Does the entry exist?
  err, result <- fetchValue bucket, key
  return next err if err
  if result.isNotFound
    return next new restify.NotFoundError "Entry not found."
  err, result <- riak_client.deleteValue do
    * bucket: bucket
      key: key
  return next err if err
  if not result
    return next new restify.NotFoundError "Entry not found."
  res.send 204
  next!

function listkeys req, res, next
  {bucket} = req.params
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return next err if err
  if result.isNotFound
     return next new restify.NotFoundError "Entry not found."
  err, result <- riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
  return next err if err
  values = [..objectKey for result.values]
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
  riak_client := new Riak.Client ['127.0.0.1']

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

