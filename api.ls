require! {
  'basho-riak-client': Riak
  restify
  crypto
  'urlsafe-base64'
  ipware
}

riak_client = new Riak.Client do
  * 'toma.horph.com'
    'orla.horph.com'

fetchValue = (bucket, key, next) ->
  riak_client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    next

storeValue = (bucket, key, value, next) ->
  obj = new Riak.Commands.KV.RiakObject!
  obj.setContentType 'application/json'
  obj.setValue value
  riak_client.storeValue do
    * bucket: bucket
      key: key
      value: value
    (err, result) ->
      next err if err
      next!

create_bucket = (req, res, next) ->
  crypto.randomBytes 30 (ex, buf) ->
    throw ex if ex
    bucket_name = urlsafeBase64.encode buf      
    # Does this bucket exist?
    fetchValue 'buckets' bucket_name, (err, result) ->
      next err if err
      if not result.isNotFound
         # This should never happen.
         return next new restify.InternalServerError "Error, cannot create bucket #{bucket_name}."
      # Mark this bucket as taken and put in by whom.
      value =
        ip: ipware!.get_ip req
        date: new Date().toISOString()
        headers: req.headers
      
      # Store headers.
      storeValue "buckets", bucket_name, value, ->
        res.send 201, "Bucket #{bucket_name} created"
        next!

setkey = (req, res, next) ->
  bucket_name = req.params.bucket
  key = req.params.key
  value = req.params.value
  # Does this bucket exist?
  fetchValue 'buckets' bucket_name, (err, result) ->
    next err if err
    if result.isNotFound
       return next new restify.NotFoundError "No such bucket."
    obj = new Riak.Commands.KV.RiakObject!
    obj.setContentType 'text/plain'
    obj.setValue value
    storeValue bucket_name, key, obj, ->
      res.send 201, "Value set."
      next!

getkey = (req, res, next) ->
  bucket_name = req.params.bucket
  key = req.params.key
  # Does this bucket exist?
  fetchValue 'buckets' bucket_name, (err, result) ->
    next err if err
    if result.isNotFound
       return next new restify.NotFoundError "Entry not found."
    fetchValue bucket_name, key, (err, result) ->
      next err if err
      if result.isNotFound
        return next new restify.NotFoundError "Entry not found."
      res.send result.values.shift!value.toString 'utf8'
      next!

server = restify.createServer!
server.get '/createbucket/', create_bucket
server.get '/setkey/:bucket/:key/:value', setkey
server.get '/getkey/:bucket/:key', getkey
server.on 'uncaughtException' (req, res, route, err) ->
  console.log route
  throw err

server.listen 8080, ->
  console.log '%s listening at %s', server.name, server.url
