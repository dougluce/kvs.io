require! {
  chai: {expect}
  sinon
  bunyan
  'swagger-tools': {specs: {v2: spec}}
  './utils'
  '../lib/api'
  '../lib/swagger': {swagger}
}

describe "Swagger API" ->
  server = sandbox = client = json_client = null

  before (done) ->
    logger = bunyan.getLogger 'test-api'
    sandbox := sinon.sandbox.create!
    utils.stub_riak_client sandbox # Just in case.
    logstub = sandbox.stub logger
    s, c, j <- utils.startServer 8088
    [server, client, json_client] := [s, c, j]
    api.init server, logstub
    done!

  after (done) ->
    client.close!
    json_client.close!
    <- server.close
    sandbox.restore!
    done!

  specify "should validate" (done) ->
    spec.validate swagger, (err, result) ->
      throw err if err
      unless result?
        return done!
      expect result.errors, "ouch, errors" .to.eql []
