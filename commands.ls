require! {
  'basho-riak-client': Riak
  crypto
  ipware
}

MAXKEYLENGTH = 256
MAXVALUELENGTH = 65536

riak_client = null # Here to allow stubbing by tests.

fetchValue = (bucket, key, next) ->
  key .= substr 0, MAXKEYLENGTH
  riak_client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    next

storeValue = (bucket, key, value, next) ->
  key .= substr 0, MAXKEYLENGTH
  riak_client.storeValue do
    * bucket: bucket
      key: key
      value: value
    next

export init = ->
  riak_client := new Riak.Client ['127.0.0.1']

export create_bucket = (info, ip, cb) ->
  ex, buf <- crypto.randomBytes 15
  return cb ex if ex
  # URL- and hostname-safe strings.
  bucket_name = buf.toString 'base64' .replace /\+/g, '0' .replace /\//g, '1'
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket_name
  return cb err, bucket_name if err
  return cb 'bucket already exists', bucket_name if not result.isNotFound
  # Mark this bucket as taken and record by whom.
  value =
    ip: ip
    date: new Date!toISOString!
    info: info # Additional info identifying bucket creator
  <- storeValue "buckets", bucket_name, value
  cb null, bucket_name  

export listkeys = (bucket, cb) ->
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  err, result <- riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
  return cb err if err
  values = [..objectKey for result.values]
  cb null, values

export delbucket = (bucket, cb) ->
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  # Is there anything in the bucket?
  err, values <- listkeys bucket
  return cb 'not empty' if values.length > 0
  # Nope, delete it.
  err, result <- riak_client.deleteValue do
    * bucket: 'buckets'
      key: bucket
  return cb err if err
  return cb 'not found' if not result
  cb null

export setkey = (bucket, key, value, cb) ->
  value .= substr 0, MAXVALUELENGTH
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'no such bucket' if result.isNotFound
  <- storeValue bucket, key, with new Riak.Commands.KV.RiakObject!
    ..setContentType 'text/plain'
    ..setValue value
  cb!

export getkey = (bucket, key, cb) ->
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  # Yup, look for the key.
  err, result <- fetchValue bucket, key
  return cb err if err
  return cb 'not found' if result.isNotFound
  cb null, result.values.shift!value.toString 'utf8'

export delkey = (bucket, key, cb) ->
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  # Does the entry exist?
  err, result <- fetchValue bucket, key
  return cb err if err
  return cb 'not found' if result.isNotFound
  err, result <- riak_client.deleteValue do
    * bucket: bucket
      key: key
  return next err if err
  return 'not found' if result.isNotFound
  cb!
