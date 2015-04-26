require! {
  'basho-riak-client': Riak
  './utils': {clients, cleanup, deleteall, BUCKETLIST}
  async
}

[client, json_client] = clients 8080

#
# Remove bucket from the bucketlist
#

deregister = (bucket, done) ->
  console.log "Deregistering #bucket"
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
  async.each data, (bucket, done) ->
    deregister bucket, done
  , (err) ->
    client.close!
    json_client.close!
    console.log "All done."

#
# Destroy buckets that aren't registered as buckets.
#

destroy_buckets = (buckets) ->
  async.each buckets, (bucket, done) ->
    if bucket == BUCKETLIST # Should never actually happen.
      console.log "Skipping BUCKETLIST #BUCKETLIST"
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
    console.log "All done."

#
# Destroy and deregister buckets on the bucketlist.
#

destroy_bucket_list = ->
  err, req, res, data <- json_client.get "/listkeys/#BUCKETLIST"
  async.each data, (bucket, done) ->
    if bucket == BUCKETLIST # Should never actually happen.
      console.log "Skipping BUCKETLIST #BUCKETLIST"
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
    console.log "All done."

all_buckets = ->
  riak_client = new Riak.Client ['127.0.0.1']
  err, result <- riak_client.listBuckets {}
  console.log result
  if result.done
    state <- riak_client.shutdown
    console.log "State is now:"
    console.log state

to_destroy = ["T02ONB4xpAaCpMX0aj5r","JPNNXU3jiCMT7NbTNMos","50Nu3sUiK8j9d7uwlQJY","qK5F7vhq5DvIhbUFj2N0","kKWdhYU6pF45rVjjsOgN","W1GOnMUhcEyrXznx1HlR","MANWrbprScgO2Dly2VaK","7CNqMaYiqtu7tS0qzBOx","IJ1QmrTmoXyqC8wHC0q4","tsL96lK2qM4cNlVTbQMp","svNkoSKYe74c5pBKj8Iq","cni1DaTbHx8Lz5e9FrRA"]


#all_buckets!
# Destroy buckets that aren't on the test bucket list
# or on the master bucket list
#destroy_buckets ["HlWq2FQPoDvs8NYnIz4z"]
#deregister_all!
#
# destroy test buckets only.
destroy_bucket_list!
