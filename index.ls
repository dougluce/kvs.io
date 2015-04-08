require! {
  'basho-riak-client': Riak
}

client = new Riak.Client do
  * 'toma.horph.com'
    'orla.horph.com'

shutdown = -> 
  client.shutdown (state) ->
    process.exit! if state == Riak.Cluster.State.SHUTDOWN

ping = (cb) -> 
  client.ping (err, result) ->
    throw new Error(err) if err
    cb!

store = (bucket, key, value, cb) ->
  obj = new Riak.Commands.KV.RiakObject!
  obj.setContentType 'text/plain'
  obj.setValue value
  client.storeValue do
    * bucket: bucket
      key: key
      value: obj
    (err, result) ->
      throw new Error(err) if err
      cb!

fetch = (bucket, key, cb) ->
  client.fetchValue do
    * bucket: bucket
      key: key
      convertToJs: false
    (err, result) ->
      throw new Error(err) if err
      if result.values.length
        cb result.values.shift!value.toString 'utf8'
      else
        cb null

ping ->
  store "buck1" "key1" 'some kinda stahring', ->
    fetch "buck1" "key1" (res) ->
      console.log res
      shutdown!


