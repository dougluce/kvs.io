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

destroy_buckets ["qtLt9jlRkXG7p0Ezwgd2","Fm1vaO69M32k9xvS6UdV","Cl5jFVzrs9VDh0wMuRag"]
#deregister_all!
