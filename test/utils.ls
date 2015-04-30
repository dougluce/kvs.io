require! {
  chai: {expect}
  async
  'basho-riak-client': Riak
  os
  restify
  crypto
  '../lib/commands'
  domain
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
  value = result.values.shift!
  try # works in test/prod
    done null, JSON.parse value.value.toString 'utf8'
  catch # works in dev
    done null, value
  

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

export stub_riak_client = (sinon) ->
  sinon.stub Riak, "Client" ->
    fetchValue: (options, cb) ->
      {bucket, key} = options
      unless stub_riak[bucket]?[key]?
        return cb null, {isNotFound: true, values: []}
      cb null, {values: [ stub_riak[bucket][key] ]}
    storeValue: (options, cb) ->
      {bucket, key, value} = options
      stub_riak[bucket] = {} unless stub_riak[bucket]
      stub_riak[bucket][key] = value
      cb null, {}
    secondaryIndexQuery: (options, cb) ->
      {bucket, indexName, indexKey, stream} = options
      unless stub_riak[bucket] and Object.keys(stub_riak[bucket]).length > 0
        return cb null, {values: []}
      values = []
      for key in Object.keys(stub_riak[bucket])
        values.push {indexKey: null, objectKey: key}
      return cb null, {values: values}
    deleteValue: (options, cb) ->
      {bucket, key} = options
      delete stub_riak[bucket][key] if stub_riak[bucket]
      cb null, true

export startServer = (port, done) ->
  server = restify.createServer!
  runServer = ->
    <- server.listen port
    console.log '%s server listening at %s', server.name, server.url
    [client, json_client] = clients!
    done server, client, json_client
  domain.create!
    ..on 'error' (err) ->
      if /EADDRINUSE/ == err
        <- setTimeout _, 100
        console.log "Re-running on #err"
        return runServer!
      else
        throw err
    ..run runServer
