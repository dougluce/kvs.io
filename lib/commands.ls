require! {
  'basho-riak-client': Riak
  crypto
  ipware
  async
  http
}

MAXKEYLENGTH = 256
MAXVALUELENGTH = 65536

BUCKET_LIST = 'buckets'
riak_client = null # Here to allow stubbing by tests.

randomString = (cb) ->
  ex, buf <- crypto.randomBytes 15
  return cb ex if ex
  # URL- and hostname-safe strings.
  bucket_name = buf.toString 'base64' .replace /\+/g, '0' .replace /\//g, '1'
  cb null, bucket_name

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

confirm_exists = (bucket, cb, rest) ->
  err, result <- fetchValue BUCKET_LIST, bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  rest!

confirm_found = (err, result, cb, rest) ->
  return cb err if err
  return cb 'not found' if not result or result.isNotFound
  rest!

export init = ->
  riak_client := new Riak.Client ['127.0.0.1']

bvalue =
  name: 'b'
  description: "B-value, passed on to postbacks"
  required: false

firecallbacks = (bucket, func, ...args) ->
  <- process.nextTick
  err, result <- fetchValue BUCKET_LIST, bucket
  return if err # Probably oughta throw instead
  return if result.isNotFound # Probably oughta throw instead
  bucket_info = result.values[0]
  for let url, callback of bucket_info.callbacks
    req = http.request url, (res) ->
      body = ""
      res.setEncoding 'utf8'
      res.on 'data', (chunk) ->
        body += chunk
      res.on 'end', ->
        callback.log = [] unless callback.log?
        callback.log.unshift! if callback.log.length > 100 # Rotate
        callback.log.push do
          status: res.statusCode
          body: body
        <- storeValue BUCKET_LIST, bucket, bucket_info
        return

    req.on 'error', (e) ->
      callback.log = [] unless callback.log?
      callback.log.unshift! if callback.log.length > 100 # Rotate
      callback.log.push do
        status: 0,
        body: e.message
      <- storeValue BUCKET_LIST, bucket, bucket_info
  
    req.write callback.data if callback.data?
    req.end!

export newbucket = (info, ip, test, b, cb) ->
  ex, bucket_name <- randomString
  return cb ex if ex
  # Does this bucket exist?
  err, result <- fetchValue BUCKET_LIST, bucket_name
  return cb err if err
  return cb 'bucket already exists', bucket_name if not result.isNotFound
  # Mark this bucket as taken and record by whom.
  bucket_info = 
    ip: ip
    date: new Date!toISOString!
    info: info # Additional info identifying bucket creator
  bucket_info['test'] = test if test
  <- storeValue BUCKET_LIST, bucket_name, bucket_info
  cb null, bucket_name

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
  * bvalue
newbucket.rest = ['post' '/']
newbucket.success = 201
newbucket.errors =
  * 'bucket already exists'
  ...
newbucket.returnformatter = (w, bucket) -> w "Your new bucket is #bucket"
newbucket.summary = "Create a new bucket."
newbucket.description = """
# Create a new bucket.

kvs.io works on the basis of buckets.  All keys must be collected into
buckets.  A bucket's name is a 20-character random string.  This
string is created via the Yarrow algorithm using 256-bit AES seeded by
the Intel Secure Key hardware randomness generator.  It is checked
against all existing bucket names to ensure there are no collisions.

## Security of your bucket

Once created, your new bucket's name is known only to you.  If you use
only SSL-protected transmission, you can keep the bucket secure
without the need for a password, API key or other security mechanism.

Keep track of the name of the bucket!  Without it, you will lose
access to the bucket and all contents within it.

## Limitations

The kvs.io unauthenticated service only allows 5 buckets to be created
per IP per day.  Authenticated accounts are required in order to get
around this limit.

See the setkey command for other limitations on kvs.io

"""

export listkeys = (bucket, keycontains, b, cb) ->
  <- confirm_exists bucket, cb
  keycontains .= toLowerCase! if keycontains
  riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
    (err, result) ->
      values = null
      if result.values
        if keycontains
          values := [..objectKey for result.values when ..objectKey.toLowerCase!indexOf(keycontains) != -1]
        else
          values := [..objectKey for result.values]
      <- confirm_no_error err, values, cb
      listkeys bucket, keycontains, b, cb

listkeys.group = 'buckets'
listkeys.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  * name: 'keycontains'
    description: "A substring to search for."
    required: false
    in: 'query'
    type: 'string'
listkeys.rest = ['get', /^\/([^\/]{20})$/]
listkeys.mapparams = { '0': 'bucket', '1': 'keycontains' }
listkeys.success = 200
listkeys.errors =
  * 'not found'
  ...
listkeys.summary = "List keys in a bucket."
listkeys.description = """
# Find keys in a bucket

Given a bucket name, show the keys that exist in the bucket.

If the optional keycontains parameter is given, only those keys that
contain the given string are shown.

"""

listkeys.returnformatter = (w, keys) -> 
  w "Keys in bucket:"
  for key in keys
    w key

export delbucket = (bucket, b, cb) ->
  <- confirm_exists bucket, cb
  # Is there anything in the bucket?
  err, values <- listkeys bucket, null, null
  return cb 'not empty' if values.length > 0
  # Nope, delete it.
  err, result <- riak_client.deleteValue do
    * bucket: BUCKET_LIST
      key: bucket
  <- confirm_found err, result, cb
  cb null

delbucket.group = 'buckets'
delbucket.params =
  * name: 'bucket'
    description: "The bucket to delete."
    required: true
  * bvalue
delbucket.rest = ['del', '/:bucket']
delbucket.success = 204
delbucket.errors =
  * 'not empty'
    'not found'
delbucket.summary = "Delete a bucket."
delbucket.description = """
# Delete a bucket

Before deleting a bucket, you must make sure that all keys have been
removed.  This command will refuse to delete a bucket that is not
empty.

Once a bucket is deleted, its name and contents are forever lost.  It
cannot be created under the same name that it previously had.
"""

export setkey = (bucket, key, value, b, cb) ->
  <- confirm_exists bucket, cb
  <- storeValue bucket, key, with new Riak.Commands.KV.RiakObject!
    ..setContentType 'text/plain'
    ..setValue value
  firecallbacks bucket, "setkey", key, value, b
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
    description: "The key to set a value for."
    required: true
  * name: 'value'
    description: "The value for the key."
    required: true
    in: 'body'
    schema: 
      type: 'string'
  * bvalue

setkey.success = 201
setkey.rest = ['put', '/:bucket/:key']
setkey.summary = "Set the value of a key in a bucket."
setkey.description = """
# Set the value of a key in a bucket

This will set a value for the given key.

If the key doesn't exist, it will be created and set to the given
value. If the key already exists, the old value will be lost.

## Limitations

Key names are restricted to #MAXKEYLENGTH bytes maximum.  Larger key
names are not rejected but are truncated to #MAXKEYLENGTH bytes before
setting.

Values are restricted to #MAXVALUELENGTH bytes.  Larger values will
not be rejected but will be truncated before storing.

"""

export newkey = (bucket, value, b, cb) ->
  <- confirm_exists bucket, cb
  ex, key <- randomString
  return cb ex if ex
  # See if it exists
  err, result <- fetchValue bucket, key
  return cb err if err
  return cb 'bad error' if not result.isNotFound
  <- storeValue bucket, key, with new Riak.Commands.KV.RiakObject!
    ..setContentType 'text/plain'
    ..setValue value
  cb null, key

newkey.errors =
  * 'not found'
  ...
newkey.group = 'keys'
newkey.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  * name: 'value'
    description: "The value for the key."
    required: true
    in: 'body'
    schema: 
      type: 'string'
  * bvalue
newkey.success = 201
newkey.rest = ['put', '/:bucket']
newkey.summary = "Create a new key and set its value."
newkey.description = """
# Put a new value into the bucket and create a key for it

This will generate a new key and store the given value under that key.

The new key is guaranteed not to already exist.

The key is created as a random 20-character string using the Yarrow
algorithm with 256-bit AES seeded by the Intel Secure Key hardware
randomness generator.

## Limitations

Values are restricted to #MAXVALUELENGTH bytes.  Larger values will
not be rejected but will be truncated before storing.

"""

export getkey = (bucket, keys, b, cb) ->
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

getkey.group = 'keys'
getkey.params =
  * name: 'bucket'
    description: "The bucket name."
    required: true
  * name: 'key'
    description: "The key."
    required: true
  * bvalue
getkey.rest = ['get', /^\/([^\/]{20})\/([^\/]+)$/]
getkey.mapparams = {'0': 'bucket', '1': 'key'}
getkey.success = 200
getkey.errors =
  * 'not found'
  ...
getkey.summary = "Get the value of a key in a bucket."
getkey.description = """
# Get the value of a key in a bucket

This will return the value of a key in a bucket.

"""

export delkey = (bucket, key, b, cb) ->
  <- confirm_exists bucket, cb
  # Does the entry exist?
  err, result <- fetchValue bucket, key
  <- confirm_found err, result, cb
  err, result <- riak_client.deleteValue do
    * bucket: bucket
      key: key
  <- confirm_found err, result, cb
  cb null

delkey.group = 'keys'
delkey.params =
  * name: 'bucket'
    description: "The bucket with this key."
    required: true
  * name: 'key'
    description: "The key to delete."
    required: true
  * bvalue

delkey.rest = ['del', '/:bucket/:key']
delkey.success = 204
delkey.errors =
  * 'not found'
  ...
delkey.summary = "Delete a key from a bucket."
delkey.description = """
# Delete a key from a bucket

This removes the key-value pair referenced by the given key, and is
not reversible.  If you delete a key-value pair, it is gone forever.

"""

export register_callback = (bucket, url, b, cb) ->
  <- confirm_exists bucket, cb
  err, bucket_info <- fetchValue BUCKET_LIST, bucket
  bucket_info = bucket_info.values[0]
  if bucket_info.callbacks
    callbacks = bucket_info.callbacks
  else
    callbacks = bucket_info.callbacks = {}
  callbacks[url] = 
    method: 'GET'
    data: null
    log: []
  <- storeValue BUCKET_LIST, bucket, bucket_info
  cb null

register_callback.group = 'buckets'
register_callback.params =
  * name: 'bucket'
    description: "The bucket to register a callback on."
    required: true
  * name: 'url'
    description: "The URL to fire on bucke change"
    required: true
    in: 'query'
    type: 'string'
  * bvalue
register_callback.rest = ['put', '/:bucket/:url']
register_callback.success = 201
register_callback.errors =
  * 'not found'
  ...
register_callback.summary = "Register a bucket callback."
register_callback.description = """
# Register a bucket callback

Any change to the given bucket is communicated to the URLs registered
through this call.  Your URL can contain macros that will expand to
values upon callback.

Macros supported:

+ %o API operation
  Will be one of: 
  newbucket, listkeys, delbucket, setkey, newkey, getkey, delkey, register_callback
+ %p operation parameters
  newbucket: bucket -- bucket created
  listkeys: bucket -- bucket keys are listed within
  delbucket: bucket -- bucket deleted
  setkey: bucket, key, value
  newkey: bucket, value
  getkey: bucket, key
  delkey: bucket, key
  register_callback: bucket, url
+ %i IP of client triggering callback
+ %b client B-value.  If a parameter named "b" is added to the client
   API call, this will contain the contents of that parameter.

"""

export list_callbacks = (bucket, b, cb) ->
  err, result <- fetchValue BUCKET_LIST, bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  bucket_info = result.values[0]
  <- confirm_no_error err, bucket_info.callbacks, cb
  list_callbacks bucket, url, b, cb

list_callbacks.group = 'buckets'
list_callbacks.params =
  * name: 'bucket'
    description: "The bucket to list callbacks on."
    required: true
  * bvalue
list_callbacks.rest = ['get', /\/callback\/^\/([^\/]{20})$/]
list_callbacks.restpath = 'callback'
list_callbacks.success = 200
list_callbacks.errors =
  * 'not found'
  ...
list_callbacks.summary = "List callbacks registered on a bucket"
list_callbacks.description = """
# List callbacks registered on a bucket

This shows a list of all URL's that are currently registered as
callbacks on the given bucket.

"""

list_callbacks.returnformatter = (w, callbacks) ->
  w "Callbacks on bucket:"
  for callback in callbacks
    w key

export delete_callback = (bucket, url, b, cb) ->
  err, result <- fetchValue BUCKET_LIST, bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  bucket_info = result.values[0]
  delete bucket_info.callbacks[url]
  <- storeValue BUCKET_LIST, bucket, bucket_info
  cb null

delete_callback.group = 'buckets'
delete_callback.params =
  * name: 'bucket'
    description: "The bucket to delete the callback from."
    required: true
  * name: 'url'
    description: "The URL to remove from callbacks."
    required: true
    in: 'query'
    type: 'string'
  * bvalue
delete_callback.rest = ['del', '/callback/:bucket']
delete_callback.restpath = 'callback'
delete_callback.success = 204
delete_callback.errors =
  * 'not found'
  ...
delete_callback.summary = "Delete a bucket callback."
delete_callback.description = """
# Delete a bucket callback."

Remove the given URL from the list of bucket callbacks.
"""
