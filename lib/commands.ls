require! {
  'basho-riak-client': Riak
  crypto
  ipware
  async
}

MAXKEYLENGTH = 256
MAXVALUELENGTH = 65536

riak_client = null # Here to allow stubbing by tests.

#
# Retry Riak connection if it errors.
# Need to augment to not reconnect in certain instances.
#
confirm_no_error = (err, result, next, cb) ->
  if err != null
    do 
      <- setTimeout _, 200
      init!
      cb!
    return
  next err, result

export fetchValue = (bucket, key, next) ->
  key .= substr 0, MAXKEYLENGTH
  riak_client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    (err, result) ->
      <- confirm_no_error err, result, next
      fetchValue bucket, key, next

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
    (err, result) ->
      <- confirm_no_error err, result, next
      storeValue bucket, key, value, next

confirm_exists = (bucket, cb, rest) ->
  err, result <- fetchValue 'buckets' bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  rest!

confirm_found = (err, result, cb, rest) ->
  return cb err if err
  return cb 'not found' if not result or result.isNotFound
  rest!

export init = ->
  riak_client := new Riak.Client ['127.0.0.1']

export newbucket = (info, ip, test, cb) ->
  ex, buf <- crypto.randomBytes 15
  return cb ex if ex
  # URL- and hostname-safe strings.
  bucket_name = buf.toString 'base64' .replace /\+/g, '0' .replace /\//g, '1'
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket_name
  return cb err if err
  return cb 'bucket already exists', bucket_name if not result.isNotFound
  # Mark this bucket as taken and record by whom.
  value =
    ip: ip
    date: new Date!toISOString!
    info: info # Additional info identifying bucket creator
  value['test'] = test if test
  <- storeValue "buckets", bucket_name, value
  cb null, bucket_name

newbucket.errors =
  * 'bucket already exists'
  ...
newbucket.group = 'buckets'
newbucket.params =
  * name: 'info'
    description: "Information about the bucket creator."
    required: true
    'x-private': true
  * name: 'ip'
    description: "IP address of the creator."
    required: true
    'x-private': true
  * name: 'test'
    description: "Marks this as a test bucket"
    required: false
    'x-private': true
newbucket.success = 201
newbucket.returnformatter = (w, bucket) -> w "Your new bucket is #bucket"
newbucket.summary = """
Create a new bucket.
"""
newbucket.description = """
Create a new bucket.
"""

export listkeys = (bucket, cb) ->
  <- confirm_exists bucket, cb
  riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
    (err, result) ->
      values = null
      if result.values
        values := [..objectKey for result.values]
      <- confirm_no_error err, values, cb
      listkeys bucket, cb

listkeys.errors =
  * 'not found'
  ...
listkeys.group = 'buckets'
listkeys.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  ...
listkeys.success = 200
listkeys.summary = """
List the keys in a bucket.
"""
listkeys.description = """
List the keys in a bucket.
"""

listkeys.returnformatter = (w, keys) -> 
  w "Keys in bucket:"
  for key in keys
    w key

export delbucket = (bucket, cb) ->
  <- confirm_exists bucket, cb
  # Is there anything in the bucket?
  err, values <- listkeys bucket
  return cb 'not empty' if values.length > 0
  # Nope, delete it.
  err, result <- riak_client.deleteValue do
    * bucket: 'buckets'
      key: bucket
  <- confirm_found err, result, cb
  cb null

delbucket.errors =
  * 'not empty'
    'not found'
delbucket.group = 'buckets'
delbucket.params =
  * name: 'bucket'
    description: "The bucket to delete."
    required: true
  ...
delbucket.success = 204
delbucket.summary = """
Delete a bucket.
"""
delbucket.description = """
Delete a bucket.
"""

export setkey = (bucket, key, value, cb) ->
  <- confirm_exists bucket, cb
  <- storeValue bucket, key, with new Riak.Commands.KV.RiakObject!
    ..setContentType 'text/plain'
    ..setValue value
  cb null

setkey.errors =
  * 'not found'
  ...
setkey.group = 'keys'
setkey.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  * name: 'key'
    description: "The key."
    required: true
  * name: 'value'
    description: "The value."
    required: true
setkey.success = 201
setkey.summary = """
Set the value of a key in a bucket.
"""
setkey.description = """
Set the value of a key in a bucket.
"""

export getkey = (bucket, keys, cb) ->
  <- confirm_exists bucket, cb
  try  # Allow multiple keys as JSON string.
    keylist = JSON.parse keys
    throw unless keylist instanceof Array
  catch
    keylist = [keys]
  keylist = keylist.map (.substr 0, MAXKEYLENGTH)
  results = {}
  found = 0
  async.each keylist, (key, done) ->
    err, result <- fetchValue bucket, key
    return done err if err
    results[key] = if not result or result.isNotFound
      null 
    else
      found++
      result.values.shift!value.toString 'utf8'
    done!
  , (err) ->
    return cb err if err
    return cb 'not found' if found == 0
    if keylist.length == 1
      results := results[keylist[0]]
    cb null, results

getkey.errors =
  * 'not found'
  ...
getkey.group = 'keys'
getkey.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  * name: 'key'
    description: "The key."
    required: true
getkey.success = 200
getkey.summary = """
Get the value of a key in a bucket.
"""
getkey.description = """
Get the value of a key in a bucket.
"""

export delkey = (bucket, key, cb) ->
  <- confirm_exists bucket, cb
  # Does the entry exist?
  err, result <- fetchValue bucket, key
  <- confirm_found err, result, cb
  err, result <- riak_client.deleteValue do
    * bucket: bucket
      key: key
  <- confirm_found err, result, cb
  cb null

delkey.errors =
  * 'not found'
  ...
delkey.group = 'keys'
delkey.params =
  * name: 'bucket'
    description: "The bucket with this key."
    required: true
  * name: 'key'
    description: "The key to delete."
    required: true
delkey.success = 204
delkey.summary = """
Delete a key from a bucket.
"""
delkey.description = """
Delete a key from a bucket.
"""

export findkeys = (bucket, keyword, cb) ->
  <- confirm_exists bucket, cb
  keyword .= toLowerCase!
  riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
    (err, result) ->
      values = null
      if result.values
        values := [..objectKey for result.values when ..objectKey.toLowerCase!indexOf(keyword) != -1]
      <- confirm_no_error err, values, cb
      findkeys bucket, cb

findkeys.errors =
  * 'not found'
  ...
findkeys.group = 'search'
findkeys.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  * name: 'keyword'
    description: "A substring to search for."
    required: true
findkeys.success = 200
findkeys.summary = """
Find keys in a bucket that contain a given substring.
"""
findkeys.description = """
Find keys in a bucket that contain a given substring.
"""

findkeys.returnformatter = (w, keys) -> 
  w "Found keys in bucket:"
  for key in keys
    w key
