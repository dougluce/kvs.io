require! {
  chai: {expect}
  restify
  he
  querystring
  './utf-cases'
  '../api'
}

server = restify.createServer!
api.init server

client = restify.createStringClient do
  * version: '*'
    url: 'http://127.0.0.1:8088'

json_client = restify.createJsonClient do
  * version: '*'
    url: 'http://127.0.0.1:8088'

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

before (done) ->
  <- server.listen 8088
  console.log '%s server listening at %s', server.name, server.url
  done!

createbucket = (done) ->
  err, req, res, data <- client.get '/createbucket'
  expect err, err .to.be.null
  expect data .to.match /^[0-9a-zA-Z]{20}$/
  expect res.statusCode .to.equal 201
  done data

setkey = (bucket, done, key = "wazoo", value="zoowahhhh") ->
  err, req, res, data <- client.get "/setkey/#{bucket}/#{key}/#{value}"
  expect err, "setkey #{err}" .to.be.null
  expect res.statusCode, "setkey status" .to.equal 201
  expect data, "setkey data" .to.be.empty
  done!

describe '/createbucket' ->
  specify 'should create a bucket' (done) ->
    (new_bucket) <- createbucket
    done!

describe '/setkey' ->
  bucket = ""
  
  before (done) ->
    (new_bucket) <- createbucket 
    bucket := new_bucket
    done!

  specify 'should set a key' (done) ->
    setkey bucket, done
    
  specify 'should fail on bad bucket' (done) ->
    err, req, res, data <- client.get "/setkey/SUPERBADBUCKETHERE/wazoo/zoowahhhh"
    expect data .to.equal err.message .to.equal 'No such bucket.'
    expect err.statusCode .to.equal 404
    done!

  describe "only the first #{KEYLENGTH} key chars count. " (done) ->
    basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string

    specify 'Add one to get the full length' (done) ->
      <- setkey bucket, _, basekey + "EXTRASTUFF"
      err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}E"
      expect data .to.equal "zoowahhhh"
      expect err, err .to.be.null
      expect res.statusCode .to.equal 200
      done!

    specify 'Add a bunch, but only the first is going to count.' (done) ->
      err, req, res, data <- client.get "/getkey/#{bucket}/#{basekey}EYUPMAN"
      expect data .to.equal "zoowahhhh"
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
      <- setkey bucket, _, key, "#{basevalue}E"
      err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
      expect data.length .to.equal VALUELENGTH
      expect data .to.equal "#{basevalue}E"
      expect err, err .to.be.null
      expect res.statusCode .to.equal 200
      done!

    specify 'Value too long?  It gets chopped.' (done) ->
      <- setkey bucket, _, key, "#{basevalue}EECHEEWAMAA"
      err, req, res, data <- client.get "/getkey/#{bucket}/#{key}"
      expect data.length .to.equal VALUELENGTH
      expect data.slice -10 .to.equal 'vvvvvvvvvE'
      expect err, err .to.be.null
      expect res.statusCode .to.equal 200
      done!

describe '/getkey' ->
  bucket = ""
  before (done) ->
    (new_bucket) <- createbucket 
    bucket := new_bucket
    setkey bucket, done

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
    (new_bucket) <- createbucket 
    bucket := new_bucket
    setkey bucket, done

  specify 'should delete a key' (done) ->
    err, req, res, data <- client.get "/delkey/#{bucket}/wazoo"
    expect data .to.be.empty
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
      <- setkey bucket, _, basekey + "EXTRASTUFF"
      err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}E"
      expect data .to.be.empty
      expect err, err .to.be.null
      expect res.statusCode, "on E delete" .to.equal 204
      done!
  
    specify 'Add a bunch, but only the first is going to count.' (done) ->
      <- setkey bucket, _, basekey + "EXTRASTUFF"
      err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}EYUPMAN"
      expect data .to.be.empty
      expect err, err .to.be.null
      expect res.statusCode, "on EYUPMAN delete" .to.equal 204
      done!
      
    specify 'Deleting the original key (one too short) should fail.' (done) ->
      <- setkey bucket, _, basekey + "EXTRASTUFF"
      err, req, res, data <- client.get "/delkey/#{bucket}/#{basekey}"
      expect data .to.equal err.message .to.equal 'Entry not found.'
      expect err.statusCode, "on truncated delete" .to.equal 404
      done!
  
describe '/listkeys' ->
  bucket = ""
  
  basekey = Array KEYLENGTH .join 'x' # For key length checking

  before (done) ->
    (new_bucket) <- createbucket 
    bucket := new_bucket
    <- setkey bucket, _, "woohoo"
    <- setkey bucket, _, "werp"
    <- setkey bucket, _, "StaggeringlyLessEfficient"
    <- setkey bucket, _, "EatingItStraightOutOfTheBag"
    <- setkey bucket, _, "#{basekey}WHOP"
    <- setkey bucket, _, "#{basekey}WERP" # Should get lost...
    <- setkey bucket, _, "#{basekey}"
    setkey bucket, done

  specify 'should list keys' (done) ->
    err, req, res, data <- client.get "/listkeys/#{bucket}"
    expect err, err .to.be.null
    expect res.statusCode .to.equal 200
    objs = JSON.parse data
    expect objs .to.have.members ["wazoo","werp","woohoo","StaggeringlyLessEfficient","EatingItStraightOutOfTheBag", "#{basekey}W", basekey]
    done!

  specify 'should list JSON keys' (done) ->
    err, req, res, data <- json_client.get "/listkeys/#{bucket}"
    expect err, err .to.be.null
    expect res.statusCode .to.equal 200
    expect data .to.have.members ["wazoo","werp","woohoo","StaggeringlyLessEfficient","EatingItStraightOutOfTheBag", "#{basekey}W", basekey]
    done!

describe '/delbucket' ->
  bucket = ""

  beforeEach (done) ->
    (new_bucket) <- createbucket
    bucket := new_bucket
    done!

  specify 'should delete the bucket' (done) ->
    err, req, res, data <- client.get "/delbucket/#{bucket}"
    expect data .to.be.empty
    expect err, err .to.be.null
    expect res.statusCode .to.equal 204
    done!

  specify 'should fail on unknown bucket' (done) ->
    err, req, res, data <-client.get "/delbucket/1WKEcUzO2EHlgtqoUzhD"
    expect data .to.equal err.message .to.equal 'Entry not found.'
    expect err.statusCode .to.equal 404
    done!

  specify 'should fail if bucket has entries' (done) ->
    <- setkey bucket, _, "Yup"
    err, req, res, data <- client.get "/delbucket/#{bucket}"
    expect data .to.equal err.message .to.equal 'Remove all keys from the bucket first.'
    expect err.statusCode .to.equal 403
    # Delete the key.
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
    (new_bucket) <- createbucket
    bucket := new_bucket
    done!
    
  utf_case_get = (tag, utf_string) ->
    # per rfc3986.txt, all URL's are %-encoded.
    key = querystring.escape utf_string
    specify tag, (done) ->
      <- setkey bucket, _, key, querystring.escape utf_string
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

  describe 'gets' ->
    for tag, utf_string of utfCases
      utf_case_get tag, utf_string

  describe 'posts' ->
    for tag, utf_string of {'d': utfCases['Danish']}
      utf_case_post tag, utf_string

#
# come up with a Riak-stubbed version for quicker unit
# tests.
#
