require! {
  ws: {Server}
  ipware
  './commands'
  bunyan
}

#logger = bunyan.getLogger 'websocket'

export accept_upgrade = (req, socket, head) ->
  ws_server = new Server noServer: true
  ws_server.handleUpgrade req, socket, head, (ws) ->
    ws.on 'message' (data, flags) ->
      errors = []
      try
        o = JSON.parse data
      catch {message}
        return ws.send JSON.stringify {success: false, errors: ["Could not parse command",message]}
      if commands[o.command].params
        command = commands[o.command]
        pp = []
        facts = o with 
          info: req.headers
          ip: ipware!get_ip req
        for param in command.params
          if facts[param['name']]
            pp.push facts[param['name']].toString!
          else if param['required']
            errors.push "#{param['name']} required"
          else pp.push null
        unless errors.length == 0
          return ws.send JSON.stringify {errors: errors, success: false}
        pp.push (err, result) ->
          return ws.send JSON.stringify {errors: [err], success: false} if err
          o = {}
          o.result = result if result
          o.success = true
          ws.send JSON.stringify o
          pp.pop! # Remove callback for reporting.
          #logger.info pp, "ws: name"
        command.apply commands, pp
