require! {
  'basho-riak-client': Riak
  crypto
  ipware
}

MAXKEYLENGTH = 256
MAXVALUELENGTH = 65536

riak_client = null # Here to allow stubbing by tests.

export fetchValue = (bucket, key, next) ->
  key .= substr 0, MAXKEYLENGTH
  riak_client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    next

export storeValue = (bucket, key, value, next) ->
  key .= substr 0, MAXKEYLENGTH
  if typeof value == 'string'
    value .= substr 0, MAXVALUELENGTH
  if typeof value == 'object' and value.value
    value.value .= substr 0, MAXVALUELENGTH
  riak_client.storeValue do
    * bucket: bucket
      key: key
      value: value
    next

export init = ->
  riak_client := new Riak.Client ['127.0.0.1']

export newbucket = (info, ip, cb) ->
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

newbucket.params =
  * info: "Information about the bucket creator.", private: true
  * ip: "IP address of the creator.", private: true
newbucket.success = 201
newbucket.returnformatter = (w, bucket) -> w "Your new bucket is #bucket"

newbucket.doc = """
Create a new bucket.
"""

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

listkeys.params =
  * bucket: "The bucket name."
  ...
listkeys.success = 200
listkeys.doc = """
List the keys in a bucket.
"""

listkeys.returnformatter = (w, keys) -> 
  w "Keys in bucket:"
  for key in keys
    w key

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

delbucket.params =
  * bucket: "The bucket to delete."
  ...
delbucket.success = 204
delbucket.doc = """
Delete a bucket.
"""

export setkey = (bucket, key, value, cb) ->
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'no such bucket' if result.isNotFound
  <- storeValue bucket, key, with new Riak.Commands.KV.RiakObject!
    ..setContentType 'text/plain'
    ..setValue value
  cb null
setkey.params =
  * bucket: "The bucket name."
  * key: "The key."
  * value: "The value."
setkey.success = 201
setkey.doc = """
Set the value of a key in a bucket.
"""

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
getkey.params =
  * bucket: "The bucket name."
  * key: "The key."
getkey.success = 200
getkey.doc = """
Get the value of a key in a bucket.
"""

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
  cb null
delkey.params =
  * bucket: "The bucket with this key."
  * key: "The key to delete."
delkey.success = 204
delkey.doc = """
Delete a key from a bucket.
"""
