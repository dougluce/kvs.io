require! {
  'basho-riak-client': Riak
  restify
  crypto
  ipware
}

riak_client = new Riak.Client ['toma.horph.com']

fetchValue = (bucket, key, next) ->
  riak_client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    next

storeValue = (bucket, key, value, next) ->
  riak_client.storeValue do
    * bucket: bucket
      key: key
      value: value
    (err, result) ->
      next err if err
      next!

create_bucket = (req, res, next) ->
  ex, buf <- crypto.randomBytes 30
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
    date: new Date().toISOString()
    headers: req.headers
  # Store headers.
  <- storeValue "buckets", bucket_name, value
  res.send 201, bucket_name
  next!

setkey = (req, res, next) ->
  {bucket, key, value} = req.params

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

getkey = (req, res, next) ->
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

exports.init = (server) ->
  server.get '/createbucket/', create_bucket
  server.get '/setkey/:bucket/:key/:value', setkey
  server.get '/getkey/:bucket/:key', getkey
  req, res, route, err <- server.on 'uncaughtException' 
  throw err

if !module.parent # Run stand-alone
  server = restify.createServer!
  exports.init server
  <- server.listen 8080
  console.log '%s listening at %s', server.name, server.url
