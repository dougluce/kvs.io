require! {
#  chai: {expect}
#  sinon
  restify
}

client = restify.createJsonClient do
  * version: '*'
    url: 'http://127.0.0.1:8080'

describe '/' ->
  specify 'should get a 200 response', (done) ->
    client.get '/createbucket', (err, req, res, data) ->
      return throw new Error err if err;
      if data.code != 200
        throw new Error 'invalid response from /hello/world'
      done!
