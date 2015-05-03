require! {
  chai: {expect}
  async
  'basho-riak-client': Riak
  os
  restify
  crypto
  '../lib/commands'
  domain
  net
}

#
# Set keys for test buckets in this bucket, so they can be
# cleanly disposed of later.
#

export BUCKETLIST = "dPrxUTPoaj7ODc769zy1"

now = new Date!
riak_client = client = json_client = null

export clients = (port = 8088, host = "127.0.0.1") ->
  client := restify.createStringClient do
    * version: '*'
      url: "http://#host:#port"
      
  json_client := restify.createJsonClient do
    * version: '*'
      url: "http://#host:#port"
  
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
  test = false
  if process.env.NODE_ENV != 'production'
    test = "env #{process.env.NODE_ENV}"
  err, bucket <- commands.newbucket "Run on #{os.hostname!} at #now", "127.0.0.1", test
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
    keys := [..objectKey for result.values]
    async.each keys, (key, done) ->
      err, result <- riak_client.deleteValue do
        * bucket: bucket
          key: key
      done!
    , cb
  , ->
    keys.length > 0
  err, result <- riak_client.deleteValue do
    * bucket: 'buckets'
      key: bucket
  expect err, "delbucket #err" .to.be.null
  done!

export cull_test_buckets = (done) ->
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
      unless stub_riak[bucket]
        return cb null, {values: []}
      values = [{indexKey: null, objectKey: key} \
        for key in Object.keys(stub_riak[bucket])]
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

export class Connector
  buffer = ''
  count = 0
  cb = client = null
  
  (host, port, connect_cb) ->
    client := net.connect port, '127.0.0.1', ->
      buffer := ''
      connect_cb client
    client.on 'end', (data) ->
      lines = buffer.split /\r\n/
      cb lines.splice 0, count
    client.on 'data', (data) ->
      buffer += data.toString!
      lines = buffer.split /\r\n/
      if lines.length >= count and (lines[lines.length-1].length > 0)
        ret = lines.splice 0, count
        buffer := lines.join "\r\n"
        cb ret

  end: ->
    client.end!

  wait_end: (cb) ->
    client.on 'end' cb

  wait: (new_count, new_cb) ->
    cb := new_cb
    count := new_count

  send: (data, new_count, new_cb) ->
    cb := new_cb
    count := new_count
    client.write data + "\r"

  rest: (cb) ->
    lines = buffer.split /\r\n/
    buffer := ''
    cb lines
  
