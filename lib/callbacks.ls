require! {
  http
}

commands = null

export firecallbacks = (bucket, func, ...args) ->
  <- process.nextTick
  err, result <- commands.fetchValue commands.BUCKET_LIST, bucket
  return if err # Probably oughta throw instead
  return if result.isNotFound # Probably oughta throw instead
  bucket_info = result.values[0]
  for let url, callback of bucket_info.callbacks
    req = http.request url, (res) ->
      body = ""
      res.setEncoding 'utf8'
      res.on 'data', (chunk) ->
        body += chunk
      res.on 'end', ->
        callback.log = [] unless callback.log?
        callback.log.unshift! if callback.log.length > 100 # Rotate
        callback.log.push do
          status: res.statusCode
          body: body
        <- commands.storeValue commands.BUCKET_LIST, bucket, bucket_info
        return

    req.on 'error', (e) ->
      callback.log = [] unless callback.log?
      callback.log.unshift! if callback.log.length > 100 # Rotate
      callback.log.push do
        status: 0,
        body: e.message
      <- commands.storeValue commands.BUCKET_LIST, bucket, bucket_info
  
    req.write callback.data if callback.data?
    req.end!

didinit = null
export init = (commands_module) ->
  commands := commands_module
  return if didinit != null
  didinit := 1
