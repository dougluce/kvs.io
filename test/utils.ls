require! {
  chai: {expect}
  async
  'basho-riak-client': Riak
  os
  restify
  crypto
}

#
# Set keys for test buckets in this bucket, so they can be
# cleanly disposed of later.
#

export BUCKETLIST = "dPrxUTPoaj7ODc769zy1"

now = new Date!
riak_client = client = json_client = null

MAXKEYLENGTH = 256
MAXVALUELENGTH = 65536

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

export setkey = (bucket, done, key = "wazoo", value="zoowahhhh") ->
  err, req, res, data <- client.get "/setkey/#{bucket}/#{key}/#{value}"
  expect err, "setkey #bucket -- #key/#value #err" .to.be.null
  expect res.statusCode, "setkey status" .to.equal 201
  expect data, "setkey data" .to.be.empty
  done!

setkey_json = (bucket, done, key = "wazoo", value="zoowahhhh") ->
  err, req, res, data <- json_client.post "/setkey" do
    * bucket: bucket
      key: key
      value: value
  expect err, "setkey #bucket -- #key/#value #err" .to.be.null
  expect res.statusCode, "setkey status" .to.equal 201
  expect data, "setkey data" .to.be.empty
  done!

test_buckets = [] # Keep track of for later removal.

export mark_bucket = (bucket, done) ->
  # Mark this bucket as being a test one.
  <- storeValue bucket, "testbucketinfo", "Run on #{os.hostname!} at #now"
  # Track this bucket locally
  test_buckets.push bucket
  # and globally, for later cleanup.
  <- storeValue BUCKETLIST, bucket, "Run on #{os.hostname!} at #now"
  done!
  
# Mark means to mark it for later deletion.
# Set false for tests that will delete the bucket.
export newbucket = (mark, done) ->
  ex, buf <- crypto.randomBytes 15
  expect ex .to.be.null
  # URL- and hostname-safe strings.
  bucket_name = buf.toString 'base64' .replace /\+/g, '0' .replace /\//g, '1'
  # Does this bucket exist?
  err, result <- fetchValue 'buckets' bucket_name
  expect err .to.be.null
  expect result.isNotFound .to.be.true
  # Mark this bucket as taken and record by whom.
  value =
    ip: "127.0.0.1"
    date: new Date!toISOString!
    info: "Run on #{os.hostname!} at #now"
  <- storeValue "buckets", bucket_name, value
  if mark
    <- mark_bucket bucket_name
    done bucket_name
  else
    done bucket_name  

# Delete everything in a bucket
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


