require! {
  chai: {expect}
  restify
  querystring
  sinon
  './utils': {after_all, newbucket, clients, mark_bucket, BUCKETLIST, clients}
  './utf-cases'
  'basho-riak-client': Riak
  '../commands'
  crypto
  domain
}

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

stub_riak =
  * "#BUCKETLIST": {}
    'buckets': {"#BUCKETLIST": 'yup'}

DEBUG = false
stub_riak_client =
  fetchValue: (options, cb) ->
    {bucket, key} = options
    console.log "fetching #bucket/#key" if DEBUG
    unless stub_riak[bucket]
      return cb null, {isNotFound: true, values: []}
    unless stub_riak[bucket][key]
      return cb null, {isNotFound: true, values: []}
    cb null, {values: [stub_riak[bucket][key]]}
  storeValue: (options, cb) ->
    {bucket, key, value} = options
    console.log "Storing #bucket/#key <- #value" if DEBUG
    unless stub_riak[bucket]
      stub_riak[bucket] = {}
    stub_riak[bucket][key] = value
    cb null, {}
  secondaryIndexQuery: (options, cb) ->
    {bucket, indexName, indexKey, stream} = options
    if stub_riak[bucket] and Object.keys(stub_riak[bucket]).length > 0
      values = []
      for key in Object.keys(stub_riak[bucket])
        values.push {indexKey: null, objectKey: key}
      return cb null, {values: values}
    cb null, {values: []}
  deleteValue: (options, cb) ->
    {bucket, key} = options
    console.log "Deleting #bucket/#key" if DEBUG
    if stub_riak[bucket]
      delete stub_riak[bucket][key]
    cb null, true

sandbox = client = json_client = null

describe "Commands" ->
  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      sandbox.stub Riak, "Client", ->
        stub_riak_client
    commands.init!
    clients!
    done!

  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    <- after_all
    sandbox.restore!
    done!
  
  describe '/newbucket' ->
    specify 'should create a bucket' (done) ->
      err, new_bucket <- commands.new_bucket "Info string", "192.231.221.256"
      expect err, "newbucket #err" .to.be.null
      expect new_bucket .to.match /^[0-9a-zA-Z]{20}$/
      <- mark_bucket new_bucket
      done!
  
    specify 'crypto error on bucket creation' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb "Crypto error"
      err, new_bucket <- commands.new_bucket  "Info string", "192.231.221.257"
      expect err .to.equal 'Crypto error'
      expect new_bucket .to.be.undefined
      done!
  
    specify 'Bad bucket creation error' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb null, "INEXPLICABLYSAMERANDOMDATA"
      err, new_bucket <- commands.new_bucket  "Info string", "192.231.221.257"
      expect err .to.equal null
      expect new_bucket .to.equal "INEXPLICABLYSAMERANDOMDATA"
      
      err, new_bucket <- commands.new_bucket  "Info string", "192.231.221.257"
      expect err, err .to.equal 'bucket already exists'
      done!
  
  describe '/setkey' ->
    bucket = ""
    
    before (done) ->
      (new_bucket) <- newbucket true
      bucket := new_bucket
      done!
  
    specify 'should set a key' (done) ->
      err <- commands.setkey bucket, "whatta", "maroon"
      expect err,err .to.be.null
      done!

    specify 'should fail on bad bucket' (done) ->
      err <- commands.setkey "SOMEKINDABADBUCKET", "whatta", "maroon"
      expect err .to.equal 'no such bucket'
      done!
  
    describe "only the first #{KEYLENGTH} key chars count. " (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        err <- commands.setkey bucket, basekey + "EXTRASTUFF", 'verlue'
        expect err,err .to.be.null
        err, value <- commands.getkey bucket, basekey + "E"
        expect err,err .to.be.null
        expect value .to.equal "verlue"
        done!
  
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        err <- commands.setkey bucket, basekey + "EJOINDER", 'verlue'
        err <- commands.setkey bucket, basekey + "EYUPNO", 'varloe'
        err <- commands.setkey bucket, basekey + "EYUPYUP", 'verlux'
        expect err,err .to.be.null

        err, value <- commands.getkey bucket, basekey + "EYUPMAN"
        expect err,err .to.be.null
        expect value .to.equal "verlux"
        done!
  
      specify 'Getting the original base key (one too short) should fail.' (done) ->
        err <- commands.setkey bucket, basekey + "PARSIMONIC", 'verlux'
        err, value <- commands.getkey bucket, basekey
        expect err .to.equal 'not found'
        expect value .to.be.undefined
        done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
      key = "setkey-valuetest"
  
      specify 'Add one to get the full length' (done) ->
        err <- commands.setkey bucket, key, "#{basevalue}E" 
        err, value <- commands.getkey bucket, key
        expect value.length .to.equal VALUELENGTH
        expect value .to.equal "#{basevalue}E"
        expect err, err .to.be.null
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        err <- commands.setkey bucket, key, "#{basevalue}EECHEEWAMAA"
        err, value <- commands.getkey bucket, key
        expect value.length .to.equal VALUELENGTH
        expect value.slice -10 .to.equal 'vvvvvvvvvE'
        expect err, err .to.be.null
        done!
  
  describe '/getkey' ->
    bucket = ""
    before (done) ->
      (new_bucket) <- newbucket true
      bucket := new_bucket
      commands.setkey bucket, "warzoo", "nozoo", done
  
    specify 'should get a key' (done) ->
      err, value <- commands.getkey bucket, 'warzoo'
      expect value .to.equal "nozoo"
      expect err, err .to.be.null
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err, value <- commands.getkey "5FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD", 'warzoo'
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
    specify 'should fail on unknown key' (done) ->
      err, value <- commands.getkey bucket, 'wazoo'
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
  describe '/delkey' ->
    bucket = ""
  
    before (done) ->
      (new_bucket) <- newbucket true
      bucket := new_bucket
      done!

    beforeEach (done) ->
      commands.setkey bucket, "parzoo", "amzoo", done
      
    specify 'should delete a key' (done) ->
      err <- commands.delkey bucket, 'parzoo'
      expect err, err .to.be.null
      # Make sure it's gone.
      err, value <- commands.getkey bucket, 'parzoo'
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err <- commands.delkey '1WKEcUzO2EHlgtqoUzhD', 'parzoo'
      expect err, err .to.equal 'not found'
      # Make sure it's gone.
      done!
  
    specify 'should fail on unknown key' (done) ->
      err <- commands.delkey bucket, 'lkdsfjlakdfsj'
      expect err, err .to.equal 'not found'
      done!
      
    describe "only the first #{KEYLENGTH} key chars count" (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", "hamzoo"
        err <- commands.delkey bucket, "#{basekey}E"
        expect err, err .to.be.null
        done!
    
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", 'whatta'
        err <- commands.delkey bucket, "#{basekey}EYUPMAN"
        expect err, err .to.be.null
        done!
        
      specify 'Deleting the original key (one too short) should fail.' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", 'whatyo'
        err <- commands.delkey bucket, basekey
        expect err, err .to.equal 'not found'
        done!
    
  describe '/listkeys' ->
    bucket = ""
    
    basekey = Array KEYLENGTH .join 'x' # For key length checking
  
    before (done) ->
      @timeout 10000
      (new_bucket) <- newbucket true
      bucket := new_bucket
      <- commands.setkey bucket, "woohoo", "value here"
      <- commands.setkey bucket, "werp", "value here"
      <- commands.setkey bucket, "StaggeringlyLessEfficient", "value here"
      <- commands.setkey bucket, "EatingItStraightOutOfTheBag", "value here"
      <- commands.setkey bucket, "#{basekey}WHOP", "value here"
      <- commands.setkey bucket, "#{basekey}WERP", "value here" # Should get lost...
      <- commands.setkey bucket, "#{basekey}", "value here"
      done!
  
    specify 'should list keys' (done) ->
      err, values <- commands.listkeys bucket
      expect err, err .to.be.null
      expect values .to.have.members ["testbucketinfo", "werp", "woohoo", "StaggeringlyLessEfficient", "EatingItStraightOutOfTheBag", "#{basekey}W", basekey]
      done!
  
  describe '/delbucket' ->
    bucket = ""
  
    beforeEach (done) ->
      (new_bucket) <- newbucket false
      bucket := new_bucket
      <- commands.setkey bucket, "junkbucketfufto", 'whatyo'
      done!
  
    specify 'should delete the bucket' (done) ->
      err <- commands.delkey bucket, "junkbucketfufto"
      expect err, err .to.be.null
      err <- commands.delbucket bucket
      expect err, "second err" .to.be.null  # TODO: UNIFY THESE!!!
      done!
  
    specify 'should fail on unknown bucket' (done) ->
      err <- commands.delkey bucket, "1WKEcUzO2EHlgtqoUzhD"
      expect err, err .to.equal 'not found'
      done!
  
    specify 'should fail if bucket has entries' (done) ->
      err <- commands.delbucket bucket
      expect err, "second err" .to.equal 'not empty'
      # Delete the keys.
      err <- commands.delkey bucket, "junkbucketfufto"
      expect err, err .to.be.null  # TODO: UNIFY THESE!!!
      # Then try to delete the bucket again.
      err <- commands.delbucket bucket
      expect err, "second err" .to.be.null  # TODO: UNIFY THESE!!!
      done!
  
  describe 'utf-8' ->
    bucket = ""
  
    before (done) ->
      (new_bucket) <- newbucket true
      bucket := new_bucket
      done!
      
    #
    # Trim the huge number of UTF cases in development to shorten test
    # runs while still getting some coverage.
    #
    if process.env.NODE_ENV == 'development'
      driver = (case_runner) ->
        keys = Object.keys utfCases
        for til 10
          key_number = Math.floor(keys.length * Math.random())
          tag = keys.splice(key_number,1)
          utf_string = utfCases[tag]
          case_runner(tag, utf_string)
    else
      driver = (case_runner) ->
        for tag, utf_string of utfCases
          case_runner tag, utf_string
  
    describe 'gets' ->
      driver (tag, utf_string) ->
        specify tag, (done) ->
          err <- commands.setkey bucket, utf_string, utf_string
          expect err, "UCG1 err" .to.be.null
          err, value <- commands.getkey bucket, utf_string
          expect err, "UCG2 err" .to.be.null      
          expect value,"value no match" .to.equal utf_string
          done!
  

