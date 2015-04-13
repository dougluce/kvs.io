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

create_bucket = (req, res, next) ->
  crypto.randomBytes 30 (ex, buf) ->
    throw ex if ex
    bucket_name = urlsafeBase64.encode buf      
    # Does this bucket exist?
    riak_client.fetchValue do
      * bucket: "buckets"
        key: bucket_name
        convertToJs: false
      (err, result) ->
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
        obj = new Riak.Commands.KV.RiakObject!
        obj.setContentType 'application/json'
        obj.setValue value
        riak_client.storeValue do
          * bucket: "buckets"
            key: bucket_name
            value: value
          (err, result) ->
            next err if err
            res.send "Bucket #{bucket_name} created", 
            next!

setkey = (req, res, next) ->
  bucket_name = req.params.bucket
  key = req.params.key
  value = req.params.value
  # Does this bucket exist?
  riak_client.fetchValue do
    * bucket: "buckets"
      key: bucket_name
      convertToJs: false
    (err, result) ->
      next err if err
      if result.isNotFound
         return next new restify.NotFoundError "No such bucket."
      obj = new Riak.Commands.KV.RiakObject!
      obj.setContentType 'text/plain'
      obj.setValue value
      riak_client.storeValue do
        * bucket: bucket_name
          key: key
          value: obj
        (err, result) ->
          next err if err
          res.send "Value set.", 
          next!

getkey = (req, res, next) ->
  bucket_name = req.params.bucket
  key = req.params.key
  # Does this bucket exist?
  riak_client.fetchValue do
    * bucket: "buckets"
      key: bucket_name
      convertToJs: false
    (err, result) ->
      next err if err
      if result.isNotFound
         return next new restify.NotFoundError "Entry not found."
      riak_client.fetchValue do
        * bucket: bucket_name
          key: key
          convertToJs: false
        (err, result) ->
          next err if err
          if result.isNotFound
            return next new restify.NotFoundError "Entry not found."
          res.send result.values.shift!value.toString 'utf8'
          next!

server = restify.createServer!
server.get '/createbucket/', create_bucket
server.get '/setkey/:bucket/:key/:value', setkey
server.get '/getkey/:bucket/:key', getkey

server.listen 8080, ->
  console.log '%s listening at %s', server.name, server.url
