require! {
  chai: {expect}
  restify
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

setkey = (bucket, done, key = "wazoo") ->
  err, req, res, data <- client.get "/setkey/#{bucket}/#{key}/zoowahhhh"
  expect err, err .to.be.null
  expect res.statusCode .to.equal 201
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
    expect err.message .to.equal 'No such bucket.'
    expect err.statusCode .to.equal 404
    done!

describe '/getkey' ->
  bucket = ""
  before (done) ->
    (new_bucket) <- createbucket 
    bucket := new_bucket
    setkey bucket, done

  specify 'should get a key' (done) ->
    err, req, res, data <- client.get "/getkey/#{bucket}/wazoo"
    expect err, err .to.be.null
    expect res.statusCode .to.equal 200
    expect data .to.equal "zoowahhhh"
    done!

  specify 'should fail on bad bucket' (done) ->
    err, req, res, data <-client.get "/getkey/4FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD/mykey"
    expect err.message .to.equal 'Entry not found.'
    expect err.statusCode .to.equal 404
    done!

  specify 'should fail on unknown key' (done) ->
    err, req, res, data <- client.get "/getkey/#{bucket}/nokey"
    expect err.message .to.equal 'Entry not found.'
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
    expect err, err .to.be.null
    expect res.statusCode .to.equal 204
    # Make sure it's gone.
    err, req, res, data <- client.get "/getkey/#{bucket}/wazoo"
    expect err.message .to.equal 'Entry not found.'
    expect res.statusCode .to.equal 404
    done!

  specify 'should fail on bad bucket' (done) ->
    err, req, res, data <-client.get "/delkey/1WKEcUzO2EHlgtqoUzhD/mykey"
    expect err.message .to.equal 'Entry not found.'
    expect err.statusCode .to.equal 404
    done!

  specify 'should fail on unknown key' (done) ->
    err, req, res, data <- client.get "/delkey/#{bucket}/nomkey"
    expect err.message .to.equal 'Entry not found.'
    expect err.statusCode .to.equal 404
    done!

describe '/listkeys' ->
  bucket = ""

  before (done) ->
    (new_bucket) <- createbucket 
    bucket := new_bucket
    <- setkey bucket, _, "woohoo"
    <- setkey bucket, _, "werp"
    <- setkey bucket, _, "StaggeringlyLessEfficient"
    <- setkey bucket, _, "EatingItStraightOutOfTheBag"
    setkey bucket, done

  specify 'should list keys' (done) ->
    err, req, res, data <- client.get "/listkeys/#{bucket}"
    expect err, err .to.be.null
    expect res.statusCode .to.equal 200
    objs = JSON.parse data
    expect objs .to.have.members ["wazoo","werp","woohoo","StaggeringlyLessEfficient","EatingItStraightOutOfTheBag"]
    done!

  specify 'should list JSON keys' (done) ->
    err, req, res, data <- json_client.get "/listkeys/#{bucket}"
    expect err, err .to.be.null
    expect res.statusCode .to.equal 200
    expect data .to.have.members ["wazoo","werp","woohoo","StaggeringlyLessEfficient","EatingItStraightOutOfTheBag"]
    done!

# All Sorts of Keys and Values Encoding:
#  - Unicode
#  - Lengths:
#  - 0, 1, max-1, max, max+1
#   SuperHuge

