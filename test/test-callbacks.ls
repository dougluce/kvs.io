require! {
  http
  chai: {expect}
  './utils'
  '../lib/commands'
}

describe 'Callbacks' ->
  describe 'Registered callbacks' ->
    bucket = callback_url = null

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
        'http://localhost/one': { data: null, log: [], method: 'GET' }
        'http://localhost/two': { data: null, log: [], method: 'GET' }
      done!

    specify 'should delete a callback' (done) ->
      err <- commands.register_callback bucket, 'http://localhost/three', null
      expect err,err .to.be.null
      err <- commands.register_callback bucket, 'http://localhost/four', null
      expect err,err .to.be.null
      err <- commands.delete_callback bucket, 'http://localhost/four', null
      err, callbacks <- commands.list_callbacks bucket, null
      expect callbacks, 'slc' .to.eql do
        'http://localhost/three': { data: null, log: [], method: 'GET' }
        ...
      done!

    specify 'should fire and report on callback' (done) ->
      err <- commands.register_callback bucket, callback_url + "?morphal", null
      expect err,err .to.be.null
      err <- commands.setkey bucket, "key", "data", "whatsup"
      err, callbacks <- commands.list_callbacks bucket, null
      <- setTimeout _, 100
      expect callbacks, 'slc' .to.eql do
        * "#{callback_url}?morphal": { data: null, log: [{body: "Something /?morphal", status: 200}], method: 'GET' }
        ...
      done!

    specify 'should fire multiple callbacks' (done) ->
      err <- commands.register_callback bucket, callback_url + "?first", null
      expect err,err .to.be.null
      err <- commands.register_callback bucket, callback_url + "?second", null
      expect err,err .to.be.null
      err <- commands.setkey bucket, "key", "data", "whatsup"
      expect err,err .to.be.null
      err <- commands.setkey bucket, "key", "data", "whatdown"
      expect err,err .to.be.null
      err, callbacks <- commands.list_callbacks bucket, null
      <- setTimeout _, 100
      expect callbacks, 'slc' .to.eql do
        * "#{callback_url}?first":
            data: null
            log:
              * {body: "Something /?first", status: 200}
                {body: "Something /?first", status: 500}
            method: 'GET'
          "#{callback_url}?second":
            data: null
            log:
              * {body: "Something /?second", status: 200}
                {body: "Something /?second", status: 500}
            method: 'GET'
      done!
