require! {
  chai: {expect}
  '../lib/cli'
  '../lib/commands'
  './utils'
  sinon
  bunyan
}

describe "CLI alone" ->
  d = sandbox = telnet_server = null

  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      sandbox.stub bunyan, 'getLogger', ->
        info: sandbox.stub!
      utils.stub_riak_client sandbox

    cli.init {} # use CLI-only commands.

    telnet_server := cli.start_telnetd 7008
    d := new utils.Connector '127.0.0.1', 7008, ->
      data <- d.wait 2 # Get banner and prompt
      expect data .to.eql [cli.banner, '>']
      data <- d.send '', 1 # Enter gives prompt back.
      expect data .to.eql ['>']
      done!
  
  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    data <- d.send 'quit', 1
    expect data .to.eql ['Disconnecting.']
    <- telnet_server.close
    <- utils.cull_test_buckets
    sandbox.restore!
    done!

  specify 'help should give me help' (done) ->
    data <- d.send 'help', 5
    expect data, 'hsgmh' .to.eql do
      * 'Commands available:'
        '  quit -- Quit your session.'
        '  help -- Show help.'
        '  sleep -- Sleep for the given number of seconds.'
        '>'
    done!
    
  specify 'help help should give me help on help' (done) ->
    data <- d.send 'help help', 7
    expect data, 'hhsgmhoh'  .to.eql do
      * ''
        '  help [command]'
        ''
        'Show help.'
        '  command: Command to get help on'
        ''
        '>'
    done!

  specify 'Junk command gives me error' (done) ->
    data <- d.send 'GOOBADEE', 2
    expect data .to.eql do
      * 'That command is unknown.'
        '>'
    done!

  specify 'echo should echo' (done) ->
    data <- d.send 'echo something here man', 2
    expect data, 'ese' .to.eql do
      * 'something here man'
        '>'
    done!

  specify 'echo eats flags, removes backslashes' (done) ->
    data <- d.send 'echo -n -e \\"H3lL0WoRlD\\"', 1
    expect data[0], 'ese' .to.equal '"H3lL0WoRlD">'
    done!

  specify 'echo with no args should still echo' (done) ->
    data <- d.send 'echo', 2
    expect data, 'ese' .to.eql do
      * ''
        '>'
    done!


describe "CLI full commands" ->
  d = sandbox = telnet_server = null

  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      sandbox.stub bunyan, 'getLogger', ->
        info: sandbox.stub!
      utils.stub_riak_client sandbox

    commands.init!
    cli.init! # Full set of commands.

    telnet_server := cli.start_telnetd 7009
    d := new utils.Connector '127.0.0.1', 7009, ->
      data <- d.wait 2 # Get banner and prompt
      expect data .to.eql [cli.banner, '>']
      data <- d.send '', 1 # Enter gives prompt back.
      expect data .to.eql ['>']
      done!

  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    data <- d.send 'quit', 1
    expect data .to.eql ['Disconnecting.']
    <- telnet_server.close
    <- utils.cull_test_buckets
    sandbox.restore!
    done!

  specify 'help should give me another command' (done) ->
    data <- d.send 'help', 4
    expect data[3], 'hsgmac' .to.not.equal '>'
    data <- d.rest
    expect data[data.length-1], 'hsgmac2' .to.equal '>'
    done!

  specify 'help listkeys should give me help on listkeys' (done) ->
    data <- d.send 'help listkeys', 9
    expect data, 'hlsgmhol' .to.eql do
      * ''
        '  listkeys bucket [keycontains] [b]'
        ''
        'List keys in a bucket.'
        '  bucket: The bucket name.'
        '  keycontains: A substring to search for.'
        '  b: B-value, passed on to postbacks'
        ''
        '>'
    done!


  specify 'newbucket should create a bucket -- and show me info' (done) ->
    data <- d.send 'newbucket', 2
    expect data[0] .to.match /^Your new bucket is [0-9a-zA-Z]{20}$/
    expect data[1] .to.equal '>'
    bucket = data[0].slice(-20)
    err, result <- utils.bucket_metadata bucket
    expect result.ip .to.match /^(::ffff:)?127.0.0.1/
    expect result.info .to.match /^Via Telnet [\S+ [0-9\.]+$/
    expect result.date .to.match /^\d{4|-\d\d-\d\dT\d\d:\d\d:\d\d.\d\d\dZ$/
    done!

  specify 'not enough params means error' (done) ->
    data <- d.send 'setkey', 2
    expect data, 'nepms' .to.eql ["Not enough arguments.", '>']
    data <- d.send 'setkey hey', 2
    expect data, 'nepms2' .to.eql ["Not enough arguments.", '>']
    data <- d.send 'setkey hey what', 2
    expect data, 'nepms3' .to.eql ["Not enough arguments.", '>']
    done!

  specify 'too many params means error' (done) ->
    data <- d.send 'setkey hey whats this now guys', 2
    expect data, 'tmpms' .to.eql ["Too many arguments.", '>']
    data <- d.send 'setkey hey whats this now guys huh', 2
    expect data, 'tmpms2' .to.eql ["Too many arguments.", '>']
    done!
