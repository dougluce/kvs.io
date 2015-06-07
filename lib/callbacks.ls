require! {
  needle
  zmq: {socket}
  ip
}

pub_sock = {}
commands = null
listen_port = 80

# When the API isn't on port 80.
export set_listen_port = (port) ->
  listen_port := port

export firecallbacks = (bucket, func, ...args) ->
  <- process.nextTick
  err, result <- commands.fetchValue commands.BUCKET_LIST, bucket
  return if err # Probably oughta throw instead
  return if result.isNotFound # Probably oughta throw instead
  bucket_info = JSON.parse result.values[0].getValue!
  for let url, callback of bucket_info.callbacks
    send_body =
      event: func
      args: args
      data: callback.data
    req = needle.request callback.method, url, send_body, (err, resp) ->
      console.log err if err
      # NEED to requeeue errors!!!
      # TODO: Don't log if it's a listen callback!
      callback.log = [] unless callback.log?
      callback.log.unshift! if callback.log.length > 100 # Rotate
      callback.log.push do
        status: if err then 0 else resp.statusCode
        body: if err then err.message else resp.body
      <- commands.storeValue commands.BUCKET_LIST, bucket, bucket_info
  
export register = (bucket, url, cb) ->
  err, bucket_info <- commands.fetchValue commands.BUCKET_LIST, bucket
  bucket_info = JSON.parse bucket_info.values[0].getValue!
  if bucket_info.callbacks
    callbacks = bucket_info.callbacks
  else
    callbacks = bucket_info.callbacks = {}
  callbacks[url] = 
    method: 'POST'
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
  return cb 'not found' unless bucket_info.callbacks[url]
  delete bucket_info.callbacks[url]
  <- commands.storeValue commands.BUCKET_LIST, bucket, bucket_info
  cb null

listeners = {}

export listen = (bucket, cb) ->
#
# If the listener drops, we'll want to remove their callback.
#
  listener = (listeners.[]"#bucket".push cb) - 1
  pid = process.pid.toString!
  <- register bucket, "http://#{ip.address!}:#listen_port/respond/#listener/#{bucket}/#pid"

export respond = (req, res) ->
  # MAKE SURE IT'S FROM AN ALLOWED NETBLOCK!!
  sendmessage req.params.pid, req.params
  res.send "OK"

relay_events_to_listeners = ->
  pid = process.pid.toString!
  # consumes messages on-box
  sub_sock = socket 'sub'

  sub_sock.bindSync "ipc:///tmp/kvsio.sock.#pid"
  sub_sock.subscribe pid

  sub_sock.on 'message', (topic, messageString) ->
    message = JSON.parse messageString
    delete message.pid
    delete message.listener # TODO: May not always want to do this...
    if listeners[message.bucket]?
      for listener in listeners[message.bucket]
        listener null, message
        <- remove message.bucket, "http://#{ip.address!}:#listen_port/respond/#listener/#{message.bucket}/#pid"
      delete listeners[message.bucket]

sendmessage = (pid, message) ->
  sendit = ->
    pub_sock[pid].send [pid, JSON.stringify message]
  if pub_sock[pid]? # Got it cached?
    sendit!
  else
    pub_sock[pid] = socket 'pub' 
    pub_sock[pid].connect "ipc:///tmp/kvsio.sock.#pid"
    setTimeout sendit, 100 # Totally annoying.
    
didinit = null

export init = (commands_module, cb) ->
  commands := commands_module

  return if didinit != null
  didinit := 1
  
  relay_events_to_listeners!
