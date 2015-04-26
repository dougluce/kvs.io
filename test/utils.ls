require! {
  chai: {expect}
  async
  'basho-riak-client': Riak
  os
  restify
  crypto
  '../lib/commands'
}

#
# Set keys for test buckets in this bucket, so they can be
# cleanly disposed of later.
#

export BUCKETLIST = "dPrxUTPoaj7ODc769zy1"

now = new Date!
riak_client = client = json_client = null

export clients = (port = 8088) ->
  client := restify.createStringClient do
    * version: '*'
      url: "http://127.0.0.1:#port"
      
  json_client := restify.createJsonClient do
    * version: '*'
      url: "http://127.0.0.1:#port"
  
  riak_client :=
    riak_client := new Riak.Client ['127.0.0.1']

  return [client, json_client]

test_buckets = [] # Keep track of for later removal.

# Accesses riak directly!
export bucket_metadata = (bucket, done) ->
  err, result <- commands.fetchValue 'buckets' bucket
  return done err if err
  done null, JSON.parse result.values.shift!value.toString 'utf8'

export mark_bucket = (bucket, done) ->
  # Mark this bucket as being a test one.
  <- commands.storeValue bucket, "testbucketinfo", "Run on #{os.hostname!} at #now"
  # Track this bucket locally
  test_buckets.push bucket
  # and globally, for later cleanup.
  <- commands.storeValue BUCKETLIST, bucket, "Run on #{os.hostname!} at #now"
  done!
  
# Mark means to mark it for later deletion.
# Set false for tests that will delete the bucket.
export markedbucket = (mark, done) ->
  err, bucket <- commands.newbucket "Run on #{os.hostname!} at #now", "127.0.0.1"
  expect err .to.be.null
  if mark
    <- mark_bucket bucket
    done bucket
  else
    done bucket

# Delete everything in a bucket
# Accesses riak directly!
export deleteall = (bucket, done) ->
  keys = []
  <- async.doWhilst (cb) ->
    err, result <- riak_client.secondaryIndexQuery do
      * bucket: bucket
        indexName: '$bucket'
        indexKey: '_'
        stream: false
    expect err, "deleteall from #bucket #err" .to.be.null
    keys = [..objectKey for result.values]
    async.each keys, (key, done) ->
      err, result <- riak_client.deleteValue do
        * bucket: bucket
          key: key
      done!
    , cb
  , -> (keys.length > 0)
  err, result <- riak_client.deleteValue do
    * bucket: 'buckets'
      key: bucket
  expect err, "delbucket #err" .to.be.null
  done!

export after_all = (done) ->
  async.each test_buckets, (bucket, done) ->
    <- deleteall bucket
    done!
  , done


stub_riak =
  * "#BUCKETLIST": {}
    'buckets': {"#BUCKETLIST": 'yup'}

DEBUG = false
export stub_riak_client =
  fetchValue: (options, cb) ->
    {bucket, key} = options
    console.log "fetching #bucket/#key" if DEBUG
    unless stub_riak[bucket]
      return cb null, {isNotFound: true, values: []}
    unless stub_riak[bucket][key]
      return cb null, {isNotFound: true, values: []}
    cb null, {values: [stub_riak[bucket][key]]}
  storeValue: (options, cb) ->
    {bucket, key, value} = options
    console.log "Storing #bucket/#key <- #value" if DEBUG
    unless stub_riak[bucket]
      stub_riak[bucket] = {}
    stub_riak[bucket][key] = value
    cb null, {}
  secondaryIndexQuery: (options, cb) ->
    {bucket, indexName, indexKey, stream} = options
    if stub_riak[bucket] and Object.keys(stub_riak[bucket]).length > 0
      values = []
      for key in Object.keys(stub_riak[bucket])
        values.push {indexKey: null, objectKey: key}
      return cb null, {values: values}
    cb null, {values: []}
  deleteValue: (options, cb) ->
    {bucket, key} = options
    console.log "Deleting #bucket/#key" if DEBUG
    if stub_riak[bucket]
      delete stub_riak[bucket][key]
    cb null, true

