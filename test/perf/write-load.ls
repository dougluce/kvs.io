require! {
  restify
  '../utils'
  benchtable
  crypto
  '../../lib/commands'
  os
}

host = \localhost
port = 8080

commands.init!

client = restify.createStringClient do
  * version: '*'
    url: "http://#host:#port"

err, req, res, bucket <- client.get "/newbucket"
if err
  console.log err
  process.exit!

now = new Date!

err, req, res, data <- client.post "/setkey" do
  bucket: bucket
  key: 'testbucketinfo'
  value: "Perf run on #{os.hostname!} at #now"

if err
  console.log err
  process.exit!
  

err, req, res, data <- client.post "/setkey" do
  bucket: utils.BUCKETLIST
  key: bucket
  value: "Perf run on #{os.hostname!} at #now"
if err
  console.log err
  process.exit!

errs = 0

suite = new benchtable

bb = (defer) ->
  crypto = require 'crypto'
  ex, buf <- crypto.randomBytes 20
  key = buf.toString 'base64'
  ex, buf <- crypto.randomBytes 200
  value = buf.toString 'base64'
  err, req, res, data <- client.post "/setkey" do
    bucket: bucket
    key: key
    value: value
  console.log err if err
  errs++ if err
  defer.resolve!

suite.add 'creates' do
  'defer': true
  'fn': bb

suite.on 'cycle' (event) ->
  console.log String event.target
  console.log "Errors: #errs"

suite.run!
