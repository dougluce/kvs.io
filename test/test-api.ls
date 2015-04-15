require! {
  chai: {expect}
  restify
  '../api'
}

server = restify.createServer!
api.init server

client = restify.createJsonClient do
  * version: '*'
    url: 'http://127.0.0.1:8088'

before (done) ->
  <- server.listen 8088
  console.log '%s server listening at %s', server.name, server.url
  done!

describe '/createbucket' ->
  done <- specify 'should create a bucket'
  err, req, res, data <- client.get '/createbucket'
  expect err .to.be.null
  expect data .to.match /^[0-9a-zA-Z]{40}$/
  expect res.statusCode .to.equal 201
  done!

describe '/setkey' ->
  bucket = ""
  do 
    done <- before
    err, req, res, data <- client.get '/createbucket'
    expect err .to.be.null
    expect data .to.match /^[0-9a-zA-Z]{40}$/
    expect res.statusCode .to.equal 201
    bucket := data
    done!

  do 
    done <- specify 'should set a key'
    err, req, res, data <- client.get "/setkey/#{bucket}/wazoo/zoowahhhh"
    expect err .to.be.null
    expect res.statusCode .to.equal 201
    expect data .to.equal "Value set."
    done!

  do 
    done <- specify 'should fail on bad bucket'
    err, req, res, data <- client.get "/setkey/4FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD/wazoo/zoowahhhh"
    expect err.message .to.equal 'No such bucket.'
    expect err.statusCode .to.equal 404
    done!

describe '/getkey' ->
  bucket = ""
  do 
    done <- before
    err, req, res, data <- client.get '/createbucket'
    expect err .to.be.null
    expect data .to.match /^[0-9a-zA-Z]{40}$/
    expect res.statusCode .to.equal 201
    bucket := data
    err, req, res, data <- client.get "/setkey/#{bucket}/mykey/mydata"
    expect err .to.be.null
    done!

  do 
    done <- specify 'should get a key'
    err, req, res, data <- client.get "/getkey/#{bucket}/mykey"
    expect err .to.be.null
    expect res.statusCode .to.equal 200
    expect data .to.equal "mydata"
    done!

  do 
    done <- specify 'should fail on bad bucket'
    err, req, res, data <-client.get "/getkey/4FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD/mykey"
    expect err.message .to.equal 'Entry not found.'
    expect err.statusCode .to.equal 404
    done!

  do 
    done <- specify 'should fail on no key'
    err, req, res, data <- client.get "/getkey/#{bucket}/nokey"
    expect err.message .to.equal 'Entry not found.'
    expect err.statusCode .to.equal 404
    done!
