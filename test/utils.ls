require! {
  chai: {expect}
  async
  os
  restify
}

# Things to kill before I die
BUCKETLIST = "rWULYcVlAyMGGEpSp0DA"

now = new Date!
client = json_client = null

exports.clients = (port = 8088) ->
  client := restify.createStringClient do
    * version: '*'
      url: "http://127.0.0.1:#port"
      
  json_client := restify.createJsonClient do
    * version: '*'
      url: "http://127.0.0.1:#port"

  return [client, json_client]

exports.setkey = setkey = (bucket, done, key = "wazoo", value="zoowahhhh") ->
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

# Mark means to mark it for later deletion.
# Set false for tests that will delete the bucket.
exports.createbucket = (mark, done) ->
  err, req, res, data <- client.get '/createbucket'
  expect err, "createbucket #err" .to.be.null
  expect data .to.match /^[0-9a-zA-Z]{20}$/
  expect res.statusCode .to.equal 201
  # Mark this bucket as being a test one.
  <- setkey_json data, _, "testbucketinfo", "Run on #{os.hostname!} at #now"
  # Track this bucket locally
  test_buckets.push data if mark
  # and globally, for later cleanup.
  <- setkey_json BUCKETLIST, _, data, "Run on #{os.hostname!} at #now"
  done data

# Delete everything in a bucket
exports.deleteall = (bucket, done) ->
  keys = []
  <- async.doWhilst (cb) ->
    err, req, res, data <- json_client.get "/listkeys/#{bucket}"
    keys = data
    try
      expect err, "deleteall from #bucket #{err}" .to.be.null
      expect res.statusCode .to.equal 200
    catch
      return cb e
    async.each data, (key, done) ->
      err, req, res, data <- client.post "/delkey" do
        * bucket: bucket
          key: key
      done!
    , cb
  , -> (keys.length > 0)
  err, req, res, data <- client.get "/delbucket/#{bucket}"
  try
    expect err, "delbucket #err" .to.be.null
    expect res.statusCode .to.equal 204
    expect data .to.be.empty
  catch
    return done e
  done!

exports.after_all = (done) ->
  async.each test_buckets, (bucket, done) ->
    <- exports.deleteall bucket
    err, req, res, data <- client.get "/listkeys/#{BUCKETLIST}"
    expect err, err .to.be.null
    expect res.statusCode .to.equal 200
    done!
  , done


