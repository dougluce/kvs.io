require! {
  ws: {Server}
  ipware
  './commands'
  bunyan
}

#logger = bunyan.getLogger 'websocket'

handle_return = (ws) ->
  (err, result) ->
    return ws.send JSON.stringify {errors: [err], success: false} if err
    o = {}
    o.result = result if result
    o.success = true
    ws.send JSON.stringify o

export accept_upgrade = (req, socket, head) ->
  ws_server = new Server noServer: true
  ws_server.handleUpgrade req, socket, head, (ws) ->
    ws.on 'message' (data, flags) ->
      try
        o = JSON.parse data
      catch {message}
        return ws.send JSON.stringify {success: false, errors: ["Could not parse command",message]}
      unless o.command
        return ws.send JSON.stringify {errors: ["malformed command, see http://kvs.io"]}
      unless commands[o.command]?params
        return ws.send JSON.stringify {errors: ["command unknown"]}
      command = commands[o.command]
      facts = o with 
        info: req.headers
        ip: ipware!get_ip req
      errors = []
      pp = []
      for param in command.params
        if facts[param['name']]
          pp.push facts[param['name']].toString!
        else if param['required']
          errors.push "#{param['name']} required"
        else pp.push null
      unless errors.length == 0
        return ws.send JSON.stringify {errors: errors, success: false}
      pp.push handle_return ws
      command.apply commands, pp
