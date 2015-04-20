require! {
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

destroy_bucket_list!
