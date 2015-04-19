require! {
  './utils': {clients, cleanup, deleteall}
  async
}

bucks =  ["tt4P6UYvIUTvZMLef9ef","vMkhSkpJynfiByUAIo1b","l7Isy7bQSxKVNGdPl3s3","bS0i1pOo4RL22X6v8Pjf","KPTZqsGlLwodVfbiXyZ1","5SY4kPDMlZfcsUvLydNb","08ABIumqG6O8eSY05lGU"]

[client, json_client] = clients 8080

#
# Utility function for manual cleanup tasks.  Takes an array of bucket
# names to destroy.
#

async.each bucks, (bucket, done) ->
  console.log "Deleting #bucket"
  err <- deleteall bucket
  if err
    console.log "Errored on #bucket"
    return done err
  else
    console.log "Done with #bucket"
    done!
, (err) ->
  client.close!
  json_client.close!
  console.log "All done."

