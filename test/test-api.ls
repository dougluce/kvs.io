require! {
  chai: {expect}
  restify
  querystring
  sinon
  './utils'
  './utf-cases'
  'basho-riak-client': Riak
  '../lib/api'
  crypto
  domain
}

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

describe "API" ->
  server = sandbox = client = json_client = null

  api_setkey = (bucket, done, key = "wazoo", value="zoowahhhh") ->
    err, req, res, data <- client.get "/setkey/#{bucket}/#{key}/#{value}"
    expect err, "setkey #bucket -- #key/#value #err" .to.be.null
    expect res.statusCode, "setkey status" .to.equal 201
    expect data, "setkey data" .to.be.empty
    done!

  before (done) ->
    @timeout 3000
  
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      sandbox.stub Riak, "Client", ->
        utils.stub_riak_client
  
    server := restify.createServer!
    api.init server
  
    runServer = ->
      <- server.listen 8088
      console.log '%s server listening at %s', server.name, server.url
      [client, json_client] := utils.clients!
      done!
    domain.create!
      ..on 'error' (err) ->
        if /EADDRINUSE/ == err
          <- setTimeout _, 100
          console.log "Re-running on #err"
          return runServer!
        else
          throw err
      ..run runServer
  
  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    <- utils.after_all
    client.close!
    json_client.close!
    <- server.close
    sandbox.restore!
    done!
  
  describe '/newbucket' ->
    specify 'should create a bucket' (done) ->
      err, req, res, data <- client.get '/newbucket'
      expect err, err .to.be.null
      expect res.statusCode .to.equal 201
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
      expect err, err .to.be.null
      expect res.statusCode .to.equal 201
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
      expect err, "api.setkey #bucket #err" .to.be.null
      expect res.statusCode, "setkey status" .to.equal 201
      expect data, "setkey data" .to.be.empty
      done!
      
    specify 'should fail on bad bucket' (done) ->
      err, req, res, data <- client.get "/setkey/SUPERBADBUCKETHERE/wazoo/zoowahhhh"
      expect data .to.equal err.message .to.equal 'No such bucket.'
      expect err.statusCode .to.equal 404
      done!
  
    describe "only the first #{KEYLENGTH} key chars count. " (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF"
        err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}E"
        expect data .to.equal "zoowahhhh"
        expect err, err .to.be.null
        expect res.statusCode .to.equal 200
        done!
  
      specify 'Add a bunch, only the last counts.' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF", 'one'
        <- api_setkey bucket, _, basekey + "ENTRANCE", 'two'
        <- api_setkey bucket, _, basekey + "EPBBBBB", 'three'
        err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}EYUPMAN"
        expect data .to.equal "three"
        expect err, err .to.be.null
        expect res.statusCode .to.equal 200
        done!
  
      specify 'Getting the original base key (one too short) should fail.' (done) ->
        err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}"
        expect data .to.equal err.message .to.equal 'Entry not found.'
        expect err.statusCode .to.equal 404
        done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
      key = "setkey-valuetest"
  
      specify 'Add one to get the full length' (done) ->
        <- api_setkey bucket, _, key, "#{basevalue}E"
        err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
        expect data.length .to.equal VALUELENGTH
        expect data .to.equal "#{basevalue}E"
        expect err, err .to.be.null
        expect res.statusCode .to.equal 200
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        <- api_setkey bucket, _, key, "#{basevalue}EECHEEWAMAA"
        err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
        expect data.length .to.equal VALUELENGTH
        expect data.slice -10 .to.equal 'vvvvvvvvvE'
        expect err, err .to.be.null
        expect res.statusCode .to.equal 200
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
      expect err, err .to.be.null
      expect res.statusCode .to.equal 200
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err, req, res, data <-client.get "/getkey/4FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD/mykey"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
  
    specify 'should fail on unknown key' (done) ->
      err, req, res, data <- client.get "/getkey/#{bucket}/nokey"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode .to.equal 404
      done!
  
  describe '/delkey' ->
    bucket = ""
  
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      api_setkey bucket, done
  
    specify 'should delete a key' (done) ->
      err, req, res, data <- client.get "/delkey/#{bucket}/wazoo"
      expect data, "should delete a key" .to.be.empty
      expect err, err .to.be.null
      expect res.statusCode .to.equal 204
      # Make sure it's gone.
      err, req, res, data <- client.get "/getkey/#{bucket}/wazoo"
      expect data .to.equal err.message .to.equal 'Entry not found.'
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
        expect err, err .to.be.null
        expect res.statusCode, "on E delete" .to.equal 204
        done!
    
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        <- api_setkey bucket, _, basekey + "EXTRASTUFF"
        err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}EYUPMAN"
        expect data, "add a bunch" .to.be.empty
        expect err, err .to.be.null
        expect res.statusCode, "on EYUPMAN delete" .to.equal 204
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
      expect err, err .to.be.null
      expect res.statusCode .to.equal 200
      objs = JSON.parse data
      expect objs .to.have.members ["testbucketinfo", "wazoo", "werp", "woohoo", "StaggeringlyLessEfficient", "EatingItStraightOutOfTheBag", "#{basekey}W", basekey]
      done!
  
    specify 'should list JSON keys' (done) ->
      err, req, res, data <- json_client.get "/listkeys/#{bucket}"
      expect err, err .to.be.null
      expect res.statusCode .to.equal 200
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
      expect err, err .to.be.null
      expect res.statusCode .to.equal 204
      err, req, res, data <- client.get "/delbucket/#{bucket}"
      expect data, "should delete bucket 2" .to.be.empty
      expect err, err .to.be.null
      expect res.statusCode .to.equal 204
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
      expect err, err .to.be.null
      expect res.statusCode .to.equal 204
      err, req, res, data <- client.get "/delkey/#{bucket}/Yup"
      expect data .to.be.empty
      expect err, err .to.be.null
      expect res.statusCode .to.equal 204
      # Then try to delete the bucket again.
      err, req, res, data <- client.get "/delbucket/#{bucket}"
      expect data .to.be.empty
      expect err, err .to.be.null
      expect res.statusCode .to.equal 204
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
        expect data,"data no match" .to.equal utf_string
        expect err, "get #{tag}: #{err}" .to.be.null
        expect res.statusCode .to.equal 200
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
        expect err, "post-get #{tag}: #{err}" .to.be.null
        expect res.statusCode .to.equal 204
  
        done!
  
    #
    # Trim the huge number of UTF cases in development to shorten test
    # runs while still getting some coverage.
    #
    if process.env.NODE_ENV == 'development'
      driver = (case_runner) ->
        keys = Object.keys utfCases
        for til 10
          key_number = Math.floor(keys.length * Math.random())
          tag = keys.splice(key_number,1)
          utf_string = utfCases[tag]
          case_runner(tag, utf_string)
    else
      driver = (case_runner) ->
        for tag, utf_string of utfCases
          case_runner tag, utf_string
  
    describe 'gets' ->
      driver utf_case_get
      
    describe 'posts' ->
      driver utf_case_post
