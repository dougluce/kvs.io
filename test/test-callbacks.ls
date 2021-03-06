require! {
  http
  chai: {expect}
  sinon
  './utils'
  '../lib/commands'
}

describe 'Callbacks' ->
  actual_buckets = registered_buckets = sandbox = null

  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      utils.stub_riak_client sandbox
    commands.init!
    utils.clients!
    a, r <- utils.recordBuckets
    [actual_buckets, registered_buckets] := [a, r]
    done!

  after (done) ->
    <- utils.checkBuckets actual_buckets, registered_buckets
    sandbox.restore!
    done!

  describe 'Registered callbacks' ->
    bucket = callback_url = sandbox = null

    before (done) ->
      seen = {}
      server = http.createServer (req, res) ->
        if seen[req.url]
          res.writeHead 500, {'Content-Type': 'text/plain'}
        else
          res.writeHead 200, {'Content-Type': 'text/plain'}
          seen[req.url] = 1
        res.end "Something #{req.url}"
      server.listen 0
      <- server.on 'listening'
      callback_url := "http://localhost:#{server.address!port}"
      done!

    beforeEach (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!

    afterEach (done) ->
      <- utils.delete_bucket bucket, 'callbacks'
      done!

    specify 'should register a callback' (done) ->
      user, err <- commands.register_callback bucket, 'http://localhost', null
      expect user .to.equal bucket
      expect err,err .to.be.null
      done!

    specify 'should list callbacks' (done) ->
      user, err <- commands.register_callback bucket, 'http://localhost/one', null
      expect user .to.equal bucket
      expect err,err .to.be.null
      user, err <- commands.register_callback bucket, 'http://localhost/two', null
      expect user .to.equal bucket
      expect err,err .to.be.null
      user, err, callbacks <- commands.list_callbacks bucket, null
      expect user .to.equal bucket
      expect err,err .to.be.null
      expect callbacks, 'slc' .to.eql do
        'http://localhost/one': { data: null, log: [], method: 'POST' }
        'http://localhost/two': { data: null, log: [], method: 'POST' }
      done!

    specify 'should delete a callback' (done) ->
      user, err <- commands.register_callback bucket, 'http://localhost/three', null
      expect user .to.equal bucket
      expect err,err .to.be.null
      user, err <- commands.register_callback bucket, 'http://localhost/four', null
      expect user .to.equal bucket
      expect err,err .to.be.null
      expect user .to.equal bucket
      _, err <- commands.delete_callback bucket, 'http://localhost/four', null
      _, err, callbacks <- commands.list_callbacks bucket, null
      expect callbacks, 'sdac' .to.eql do
        'http://localhost/three': { data: null, log: [], method: 'POST' }
        ...
      done!

    specify 'should fire and report on callback' (done) ->
      timeout_scale = 100
      if process.env.NODE_ENV == 'test'
        timeout_scale := 200
      user, err <- commands.register_callback bucket, callback_url + "?morphal", null
      expect user .to.equal bucket
      expect err,err .to.be.null
      _, err <- commands.setkey bucket, "key", "data", "whatsup"
      <- setTimeout _, timeout_scale
      _, err, callbacks <- commands.list_callbacks bucket, null
      expect callbacks, 'sfaroc' .to.eql do
        * "#{callback_url}?morphal": { data: null, log: [{body: "Something /?morphal", status: 200}], method: 'POST' }
        ...
      <- utils.delete_key bucket, "key", "sdac"
      done!

    specify 'should fire multiple callbacks' (done) ->
      timeout_scale = 60
      if process.env.NODE_ENV == 'test'
        timeout_scale := 100
      @timeout 5000
      user, err <- commands.register_callback bucket, callback_url + "?first", null
      expect user .to.equal bucket
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale
      user, err <- commands.register_callback bucket, callback_url + "?second", null
      expect user .to.equal bucket
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale
      user, err <- commands.setkey bucket, "key", "data", "whatsup"
      expect user .to.equal bucket
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale
      user, err <- commands.setkey bucket, "key", "data", "whatdown"
      expect user .to.equal bucket
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale * 2
      user, err, callbacks <- commands.list_callbacks bucket, null
      expect callbacks, 'sfmc' .to.eql do
        * "#{callback_url}?first":
            data: null
            log:
              * {body: "Something /?first", status: 200}
                {body: "Something /?first", status: 500}
            method: 'POST'
          "#{callback_url}?second":
            data: null
            log:
              * {body: "Something /?second", status: 200}
                {body: "Something /?second", status: 500}
            method: 'POST'
      <- utils.delete_key bucket, "key", "sfmc"
      done!

