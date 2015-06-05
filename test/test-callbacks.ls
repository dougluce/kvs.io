require! {
  http
  chai: {expect}
  sinon
  './utils'
  '../lib/commands'
}

describe 'Callbacks' ->
  sandbox = null

  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      utils.stub_riak_client sandbox
    commands.init!
    done!

  after (done) ->
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

    specify 'should register a callback' (done) ->
      err <- commands.register_callback bucket, 'http://localhost', null
      expect err,err .to.be.null
      done!

    specify 'should list callbacks' (done) ->
      err <- commands.register_callback bucket, 'http://localhost/one', null
      expect err,err .to.be.null
      err <- commands.register_callback bucket, 'http://localhost/two', null
      expect err,err .to.be.null
      err, callbacks <- commands.list_callbacks bucket, null
      expect err,err .to.be.null
      expect callbacks, 'slc' .to.eql do
        'http://localhost/one': { data: null, log: [], method: 'POST' }
        'http://localhost/two': { data: null, log: [], method: 'POST' }
      done!

    specify 'should delete a callback' (done) ->
      err <- commands.register_callback bucket, 'http://localhost/three', null
      expect err,err .to.be.null
      err <- commands.register_callback bucket, 'http://localhost/four', null
      expect err,err .to.be.null
      err <- commands.delete_callback bucket, 'http://localhost/four', null
      err, callbacks <- commands.list_callbacks bucket, null
      expect callbacks, 'sdac' .to.eql do
        'http://localhost/three': { data: null, log: [], method: 'POST' }
        ...
      done!

    specify 'should fire and report on callback' (done) ->
      timeout_scale = 100
      if process.env.NODE_ENV == 'test'
        timeout_scale := 200
      err <- commands.register_callback bucket, callback_url + "?morphal", null
      expect err,err .to.be.null
      err <- commands.setkey bucket, "key", "data", "whatsup"
      <- setTimeout _, timeout_scale
      err, callbacks <- commands.list_callbacks bucket, null
      expect callbacks, 'sfaroc' .to.eql do
        * "#{callback_url}?morphal": { data: null, log: [{body: "Something /?morphal", status: 200}], method: 'POST' }
        ...
      done!

    specify 'should fire multiple callbacks' (done) ->
      timeout_scale = 30
      if process.env.NODE_ENV == 'test'
        timeout_scale := 100
      @timeout timeout_scale * 50
      err <- commands.register_callback bucket, callback_url + "?first", null
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale
      err <- commands.register_callback bucket, callback_url + "?second", null
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale
      err <- commands.setkey bucket, "key", "data", "whatsup"
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale
      err <- commands.setkey bucket, "key", "data", "whatdown"
      expect err,err .to.be.null
      <- setTimeout _, timeout_scale * 2
      err, callbacks <- commands.list_callbacks bucket, null
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
      done!

