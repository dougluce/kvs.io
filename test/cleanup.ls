require! {
  'basho-riak-client': Riak
  './utils': {clients, cleanup, deleteall, BUCKETLIST}
  async
}

[client, json_client] = clients 80, "kvs.io"

riak_client = new Riak.Client ['127.0.0.1']

CONCURRENCY = 20

all_keys = (bucket, cb) ->
  riak_client.secondaryIndexQuery do
    * bucket: bucket
      indexName: '$bucket'
      indexKey: '_'
      stream: false
    (err, result) ->
      return cb err if err
      values = null
      if result.values
        values := [..objectKey for result.values]
      cb values

all_buckets = (cb) ->
  buckets = []
  err, result <- riak_client.listBuckets {}
  buckets ++= result.buckets
  if result.done
    state <- riak_client.shutdown
    cb buckets if state == 4  

#
# Remove bucket from the bucketlist and registry
#

deregister = (bucket, done) ->
  if bucket == BUCKETLIST or bucket == 'buckets' # Should never actually happen.
    console.log "Skipping BUCKETLIST #bucket"
  console.log "Deregistering #bucket"
  err, result <- riak_client.deleteValue do
    * bucket: "buckets"
      key: bucket
  if err
    console.log "Errored removing #bucket: #err"
  else
    console.log "Done with #bucket"
  err, req, res, data <- client.post "/delkey" do
    * bucket: BUCKETLIST
      key: bucket
  if err
    console.log "Errored deregistering #bucket: #err"
  else
    console.log "Done with #bucket"
  done!

deregister_all = ->
  err, req, res, data <- json_client.get "/listkeys/#BUCKETLIST"
  async.eachLimit data, CONCURRENCY, (bucket, done) ->
    deregister bucket, done
  , (err) ->
    client.close!
    json_client.close!
    console.log "All done."

#
# List out keys in the registry that were made via testing
#


find_local_keys = (cb) ->
  candidate_keys <- all_keys 'buckets'
  keys = []  
  async.eachLimit candidate_keys, CONCURRENCY, (key, done) ->
    riak_client.fetchValue do
      * bucket: 'buckets'
        key: key
        convertToJs: false
      (err, result) ->
        o = JSON.parse result.values.shift!value.toString 'utf8'
        if o.test?
          keys.push key
      done!
  , (err) ->
    cb!
#
# Deregister any bucket that doesn't exist on the system.
#

prune_bucket_registry = ->
  keys <- all_keys 'buckets'
  async.eachLimit keys, CONCURRENCY, (bucket, done) ->
    if bucket == BUCKETLIST  or bucket == 'buckets' # Should never actually happen.
      console.log "Skipping BUCKETLIST #bucket"
      return done!
    riak_client.fetchValue do
      * bucket: 'buckets'
        key: bucket
        convertToJs: false
      (err, result) ->
        o = JSON.parse result.values.shift!value.toString 'utf8'
        if o.test # It's a test bucket.
          console.log "Removing test bucket #bucket from #{o.test}"
          err <- deleteall bucket
          if err
            console.log "Errored on #bucket: #err"
            return done err
          else
            deregister bucket, done
        done!
  , (err) ->
    client.close!
    json_client.close!
    console.log "All done."


#
# Destroy buckets that aren't registered as buckets.
#

destroy_buckets = (buckets) ->
  async.eachLimit buckets, CONCURRENCY, (bucket, done) ->
    if bucket == BUCKETLIST  or bucket == 'buckets' # Should never actually happen.
      console.log "Skipping BUCKETLIST #bucket"
      return done!
    console.log "Deleting #bucket"
    err <- deleteall bucket
    if err
      console.log "Errored on #bucket: #err"
      return done err
    console.log "Deleted #bucket"
    done!
  , (err) ->
    client.close!
    json_client.close!
    console.log "All destroyed."

#
# Destroy and deregister buckets on the bucketlist.
#

destroy_bucket_list = (cb) ->
  console.log "Getting bucket list"
  err, req, res, data <- json_client.get "/listkeys/#BUCKETLIST"
  console.log err
  console.log data
  async.eachLimit data, CONCURRENCY, (bucket, done) ->
    if bucket == BUCKETLIST  or bucket == 'buckets' # Should never actually happen.
      console.log "Skipping BUCKETLIST #bucket"
      return done!
    console.log "Deleting #bucket"
    err <- deleteall bucket
    if err
      console.log "Errored on #bucket: #err"
      return done err
    else
      deregister bucket, done
  , (err) ->
    client.close!
    json_client.close!
    console.log "All debucketed."
    cb!

kill_various_buckets = (cb) ->
  buckets <- all_buckets
  async.eachLimit buckets, CONCURRENCY, (bucket, done) ->
    if bucket == BUCKETLIST or bucket == 'buckets' # Should never actually happen.
      console.log "Skipping BUCKETLIST #bucket"
      return done!
    keys <- all_keys bucket
    killablekeys =
      'someDamnedThing'
      'junkbucketfufto'
      'wazoo'
      'whereabouts'
    if keys[0]? and keys[0] in killablekeys
      console.log "#bucket up for deletion"
      return deleteall bucket, done
    else
      console.log "Skipping #bucket..."
      console.log keys
      done!
  , (err) ->
    client.close!
    json_client.close!
    console.log "All listed."
    cb!

to_destroy = ["T02ONB4xpAaCpMX0aj5r","JPNNXU3jiCMT7NbTNMos","50Nu3sUiK8j9d7uwlQJY","qK5F7vhq5DvIhbUFj2N0","kKWdhYU6pF45rVjjsOgN","W1GOnMUhcEyrXznx1HlR","MANWrbprScgO2Dly2VaK","7CNqMaYiqtu7tS0qzBOx","IJ1QmrTmoXyqC8wHC0q4","tsL96lK2qM4cNlVTbQMp","svNkoSKYe74c5pBKj8Iq","cni1DaTbHx8Lz5e9FrRA"]


#all_buckets!
# Destroy buckets that aren't on the test bucket list
# or on the master bucket list
#destroy_buckets ["HlWq2FQPoDvs8NYnIz4z"]
#deregister_all!
#
# destroy test buckets only.
#<- destroy_bucket_list
#client.close!
#json_client.close!
#<- list_all_bucket_keys!

#find_local_keys!
prune_bucket_registry!
#<- kill_various_buckets!
#<- deleteall 'INEXPLICABLYSAMERANDOMDATA'
