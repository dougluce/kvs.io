require! {
  http
  zmq: {socket}
}

pub_sock = {}
commands = null

export firecallbacks = (bucket, func, ...args) ->
  <- process.nextTick
  err, result <- commands.fetchValue commands.BUCKET_LIST, bucket
  return if err # Probably oughta throw instead
  return if result.isNotFound # Probably oughta throw instead
  bucket_info = JSON.parse result.values[0].getValue!
  sendmessage process.pid.toString!, {bucket: bucket, event: func, args: args}
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

export register = (bucket, url, cb) ->
  err, bucket_info <- commands.fetchValue commands.BUCKET_LIST, bucket
  bucket_info = JSON.parse bucket_info.values[0].getValue!
  if bucket_info.callbacks
    callbacks = bucket_info.callbacks
  else
    callbacks = bucket_info.callbacks = {}
  callbacks[url] = 
    method: 'GET'
    data: null
    log: []
  <- commands.storeValue commands.BUCKET_LIST, bucket, bucket_info
  cb null

export list = (bucket, cb) ->
  err, result <- commands.fetchValue commands.BUCKET_LIST, bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  bucket_info = JSON.parse result.values[0].getValue!
  cb null, bucket_info.callbacks

export remove = (bucket, url, cb) ->
  err, result <- commands.fetchValue commands.BUCKET_LIST, bucket
  return cb err if err
  return cb 'not found' if result.isNotFound
  bucket_info = JSON.parse result.values[0].getValue!
  delete bucket_info.callbacks[url]
  <- commands.storeValue commands.BUCKET_LIST, bucket, bucket_info
  cb null

listeners = {}

export listen = (bucket, cb) ->
  listeners.[]"#bucket".push cb

  # Register a callback.
  # that lists our IP and process ID.
  # Put the callback on a list.
  # ZMQ consumer will call when an event comes in.

relay_events_to_listeners = ->
  pid = process.pid.toString!
  # consumes messages on-box
  sub_sock = socket 'sub'

  sub_sock.bindSync 'ipc:///tmp/kvsio.sock.#pid'
  sub_sock.subscribe pid

  sub_sock.on 'message', (topic, messageString) ->
    message = JSON.parse messageString
    if listeners[message.bucket]?
      for listener in listeners[message.bucket]
        listener null, message
      x = delete listeners[message.bucket]


sendmessage = (pid, message) ->
  sendit = ->
    pub_sock[pid].send [pid, JSON.stringify message]
  if pub_sock[pid]? # Got it cached?
    sendit!
  else
    pub_sock[pid] = socket 'pub' 
    pub_sock[pid].connect 'ipc:///tmp/kvsio.sock.#pid'
    setTimeout sendit, 100 # Totally annoying.
    
didinit = null

export init = (commands_module, cb) ->
  commands := commands_module

  return if didinit != null
  didinit := 1
  
  relay_events_to_listeners!
