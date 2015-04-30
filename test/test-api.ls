require! {
  chai: {expect}
  restify
  querystring
  sinon
  './utils'
  './utf-cases'
  request
  '../lib/api'
  crypto
  bunyan
}

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

check_err = (err, res, where, status) ->
  expect err, "err #where" .to.be.null
  expect res.statusCode, "status #where" .to.equal status

describe "API" ->
  server = sandbox = client = json_client = null

  api_setkey = (bucket, done, key = "wazoo", value="zoowahhhh") ->
    err, req, res, data <- client.get "/setkey/#{bucket}/#{key}/#{value}"
    check_err err, res, "setkey #bucket -- #key/#value #err", 201
    expect data, "setkey data" .to.be.empty
    done!

  before (done) ->
    @timeout 3000
    logger = bunyan.getLogger 'test-api'  
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      utils.stub_riak_client sandbox
    logstub = sandbox.stub logger
    s, c, j <- utils.startServer 8088
    [server, client, json_client] := [s, c, j]
    api.init server, logstub
    done!

  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    <- utils.cull_test_buckets
    client.close!
    json_client.close!
    <- server.close
    sandbox.restore!
    done!
  
  describe '/newbucket' ->
    specify 'should create a bucket' (done) ->
      err, req, res, data <- client.get '/newbucket'
      check_err err, res, 'scab' 201
      expect data .to.match /^[0-9a-zA-Z]{20}$/
      done!
  
    specify 'crypto error on bucket creation' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb "Crypto error"
      err, req, res, data <- client.get '/newbucket'
      expect data .to.equal err.message .to.equal 'Crypto error'
      expect err.statusCode .to.equal 500
      expect res.statusCode .to.equal 500
      done!
  
    specify 'Bad bucket creation error' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb null, "INEXPLICABLYSAMERANDOMDATA"
      err, req, res, data <- client.get '/newbucket'
      expect data .to.equal "INEXPLICABLYSAMERANDOMDATA"
      check_err err, res, 'bbce', 201
      <- utils.mark_bucket "INEXPLICABLYSAMERANDOMDATA"
      err, req, res, data <- client.get '/newbucket'
      expect data .to.equal err.message .to.equal 'cannot create bucket.'
      expect err.statusCode .to.equal res.statusCode .to.equal 500
      done!
  
  describe '/setkey' ->
    bucket = ""
    
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!
  
    specify 'should set a key' (done) ->
      err, req, res, data <- client.get "/setkey/#{bucket}/wazoo/zoowahharf"
      check_err err, res, "api.setkey #bucket #err", 201 
      expect data, "setkey data" .to.be.empty
      done!
      
    specify 'should fail on bad bucket' (done) ->
      err, req, res, data <- client.get "/setkey/SUPERBADBUCKETHERE/wazoo/zoowahhhh"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
  
    describe "only the first #{KEYLENGTH} key chars count. " (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF"
        err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}E"
        expect data .to.equal "zoowahhhh"
        check_err err, res, 'bbce', 200
        done!
  
      specify 'Add a bunch, only the last counts.' (done) ->
        timeout = 0
        timeout = 100 if process.env.NODE_ENV == 'test'
        <- api_setkey bucket, _, basekey + "EXTRASTUFF", 'one'
        <- setTimeout _, timeout
        <- api_setkey bucket, _, basekey + "ENTRANCE", 'two'
        <- setTimeout _, timeout
        <- api_setkey bucket, _, basekey + "EPBBBBB", 'three'
        <- setTimeout _, timeout
        err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}EYUPMAN"
        expect data .to.equal "three"
        check_err err, res, 'aabotlc', 200
        done!
  
      specify 'Getting the original base key (one too short) should fail.' (done) ->
        err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}"
        expect data .to.equal 'Entry not found.'
        expect res.statusCode .to.equal 404
        done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
      key = "setkey-valuetest"
  
      specify 'Add one to get the full length' (done) ->
        <- api_setkey bucket, _, key, "#{basevalue}E"
        err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
        expect data.length .to.equal VALUELENGTH
        expect data .to.equal "#{basevalue}E"
        check_err err, res, 'aotgtfl', 200
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        <- api_setkey bucket, _, key, "#{basevalue}EECHEEWAMAA"
        err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
        expect data.length .to.equal VALUELENGTH
        expect data.slice -10 .to.equal 'vvvvvvvvvE'
        check_err err, res, 'vtligc', 200
        done!
  
  describe '/getkey' ->
    bucket = ""
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      api_setkey bucket, done
  
    specify 'should get a key' (done) ->
      err, req, res, data <- client.get "/getkey/#{bucket}/wazoo"
      expect data .to.equal "zoowahhhh"
      check_err err, res, 'sgak', 200
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err, req, res, data <-client.get "/getkey/4FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD/mykey"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
  
    specify 'should fail on unknown key' (done) ->
      err, req, res, data <- client.get "/getkey/#{bucket}/nokey"
      expect data .to.equal 'Entry not found.'
      expect err.message .to.equal 'Entry not found.'
      expect res.statusCode .to.equal 404
      done!
  
  describe '/delkey' ->
    bucket = ""
  
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      api_setkey bucket, done
  
    specify 'should delete a key' (done) ->
      err, req, res, data <- client.get "/delkey/#{bucket}/wazoo"
      expect data, "should delete a key" .to.equal ""
      check_err err, res, 'sdak', 204
      # Make sure it's gone.
      err, req, res, data <- client.get "/getkey/#{bucket}/wazoo"
      expect data .to.equal 'Entry not found.'
      expect err.message .to.equal 'Entry not found.'
      expect res.statusCode .to.equal 404
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err, req, res, data <-client.get "/delkey/1WKEcUzO2EHlgtqoUzhD/mykey"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
  
    specify 'should fail on unknown key' (done) ->
      err, req, res, data <- client.get "/delkey/#{bucket}/nomkey"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
      
    describe "only the first #{KEYLENGTH} key chars count" (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF"
        err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}E"
        expect data, "full length" .to.be.empty
        check_err err, res, 'aotgtfl', 204
        done!
    
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF"
        err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}EYUPMAN"
        expect data, "add a bunch" .to.be.empty
        check_err err, res, 'aabbotfigtc', 204
        done!
        
      specify 'Deleting the original key (one too short) should fail.' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF"
        err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}"
        expect data .to.equal err.message .to.equal 'Entry not found.'
        expect err.statusCode, "on truncated delete" .to.equal 404
        done!
    
  describe '/listkeys' ->
    bucket = ""
    
    basekey = Array KEYLENGTH .join 'x' # For key length checking
  
    before (done) ->
      @timeout 5000 if process.env.NODE_ENV == 'test'
      newbucket <- utils.markedbucket true
      bucket := newbucket
      <- api_setkey bucket, _, "woohoo"
      <- api_setkey bucket, _, "werp"
      <- api_setkey bucket, _, "StaggeringlyLessEfficient"
      <- api_setkey bucket, _, "EatingItStraightOutOfTheBag"
      <- api_setkey bucket, _, "#{basekey}WHOP"
      <- api_setkey bucket, _, "#{basekey}WERP" # Should get lost...
      <- api_setkey bucket, _, "#{basekey}"
      api_setkey bucket, done
  
    specify 'should list keys' (done) ->
      err, req, res, data <- client.get "/listkeys/#{bucket}"
      check_err err, res, 'slk', 200
      expect res.statusCode .to.equal 200
      objs = JSON.parse data
      expect objs .to.have.members ["testbucketinfo", "wazoo", "werp", "woohoo", "StaggeringlyLessEfficient", "EatingItStraightOutOfTheBag", "#{basekey}W", basekey]
      done!
  
    specify 'should list JSON keys' (done) ->
      err, req, res, data <- json_client.get "/listkeys/#{bucket}"
      check_err err, res, 'sljk', 200
      expect data .to.have.members ["testbucketinfo", "wazoo", "werp", "woohoo", "StaggeringlyLessEfficient", "EatingItStraightOutOfTheBag", "#{basekey}W", basekey]
      done!
  
  describe '/delbucket' ->
    bucket = ""
  
    beforeEach (done) ->
      newbucket <- utils.markedbucket false
      <- api_setkey newbucket, _, "someDamnedThing"
      bucket := newbucket
      done!
  
    specify 'should delete the bucket' (done) ->
      err, req, res, data <- client.get "/delkey/#{bucket}/someDamnedThing"
      expect data, "should delete bucket" .to.be.empty
      check_err err, res, 'sdtb', 204
      err, req, res, data <- client.get "/delbucket/#{bucket}"
      expect data, "should delete bucket 2" .to.be.empty
      check_err err, res, 'sdtb2', 204
      done!
  
    specify 'should fail on unknown bucket' (done) ->
      err, req, res, data <-client.get "/delbucket/1WKEcUzO2EHlgtqoUzhD"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
  
    specify 'should fail if bucket has entries' (done) ->
      <- api_setkey bucket, _, "Yup"
      err, req, res, data <- client.get "/delbucket/#{bucket}"
      expect data .to.equal err.message .to.equal 'Remove all keys from the bucket first.'
      expect err.statusCode .to.equal 403
      # Delete the keys.
      err, req, res, data <- client.get "/delkey/#{bucket}/someDamnedThing"
      expect data, "should fail if entries" .to.be.empty
      check_err err, res, 'sfibha', 204
      err, req, res, data <- client.get "/delkey/#{bucket}/Yup"
      expect data .to.be.empty
      check_err err, res, 'sfibha2', 204
      # Then try to delete the bucket again.
      err, req, res, data <- client.get "/delbucket/#{bucket}"
      expect data .to.be.empty
      check_err err, res, 'sfibha3', 204
      done!
  
  describe 'utf-8' ->
    bucket = ""
  
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!
      
    utf_case_get = (tag, utf_string) ->
      # per rfc3986.txt, all URL's are %-encoded.
      key = querystring.escape utf_string
      specify tag, (done) ->
        <- api_setkey bucket, _, key, querystring.escape utf_string
        err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
        # But we expect proper UTF-8 back.
        expect data .to.equal utf_string
        check_err err, res, "get #{tag}: #{err}", 200
        done!
  
    utf_case_post = (tag, utf_string) ->
      specify tag, (done) ->
        err, req, res, data <- client.post "/setkey" do
          * bucket: bucket
            key: utf_string
            value: utf_string
        expect err, "post #{tag}: #{err}" .to.be.null
        expect res.statusCode .to.equal 201
  
        err, req, res, data <- client.post "/getkey" do
          * bucket: bucket
            key: utf_string
        expect err, "post-get #{tag}: #{err}" .to.be.null
        expect res.statusCode .to.equal 200
        expect data .to.equal utf_string
  
        err, req, res, data <- client.post "/delkey" do
          * bucket: bucket
            key: utf_string
        check_err err, res, "post-get #{tag}: #{err}", 204
        done!
  
    #
    # Trim the huge number of UTF cases in development to shorten test
    # runs while still getting some coverage.
    #
    if process.env.NODE_ENV == 'test'
      driver = (case_runner) ->
        for tag, utf_string of utfCases
          case_runner tag, utf_string
    else
      driver = (case_runner) ->
        keys = Object.keys utfCases
        for til 10
          key_number = Math.floor(keys.length * Math.random())
          tag = keys.splice(key_number,1)
          utf_string = utfCases[tag]
          case_runner(tag, utf_string)
  
    describe 'gets' ->
      driver utf_case_get
      
    describe 'posts' ->
      driver utf_case_post

  describe 'web site proxying' ->
    before (done) ->
      if process.env.NODE_ENV != 'test'
        sandbox.stub request, "get" (options) ->
          return
            pipe: (res) ->
              res.writeHead 200, "content-type": 'text/html'
              res.end 'body goes here'
        done!

    specify 'getting index.html should proxy' (done) ->
      err, req, res, data <- client.get "/index.html"
      check_err err, res, 'wsb', 200
      expect res.headers['content-type'], "index.html content" .to.equal 'text/html'
      expect data, "index.html data" .to.not.be.empty
      done!

    specify 'getting /w should proxy' (done) ->
      err, req, res, data <- client.get "/w"
      check_err err, res, 'g/wsp', 200
      expect res.headers['content-type'], "/w content" .to.equal 'text/html'
      expect data, "/w data" .to.not.be.empty
      done!
