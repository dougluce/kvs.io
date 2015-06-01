require! {
  chai: {expect}
  restify
  querystring
  sinon
  './utils'
  './utf-cases'
  '../lib/commands'
  crypto
  domain
}

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

sandbox = client = json_client = null

describe "Commands" ->
  before (done) ->
    sandbox := sinon.sandbox.create!
    if process.env.NODE_ENV != 'test'
      utils.stub_riak_client sandbox
    commands.init!
    utils.clients!
    done!

  after (done) ->
    @timeout 100000 if process.env.NODE_ENV == 'test'
    <- utils.cull_test_buckets
    sandbox.restore!
    done!
  
  describe '/newbucket' ->
    specify 'should create a bucket' (done) ->
      err, newbucket <- commands.newbucket "Info string", "192.231.221.256", "scab test", null
      expect err, "newbucket #err" .to.be.null
      expect newbucket .to.match /^[0-9a-zA-Z]{20}$/
      <- utils.mark_bucket newbucket
      done!
  
    specify 'crypto error on bucket creation' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb "Crypto error"
      err, newbucket <- commands.newbucket  "Info string", "192.231.221.257", "ceobc test", null
      expect err .to.equal 'Crypto error'
      expect newbucket .to.be.undefined
      done!
  
    specify 'Bad bucket creation error' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb null, "INEXPLICABLYSAMERANDOMDATA"
      err, newbucket <- commands.newbucket  "Info string", "192.231.221.257", 'bbce test', null
      expect err .to.equal null
      expect newbucket .to.equal "INEXPLICABLYSAMERANDOMDATA"
      
      err, newbucket <- commands.newbucket  "Info string", "192.231.221.257", 'bbce test 2', null
      expect err, err .to.equal 'bucket already exists'
      done!
  
  describe '/setkey' ->
    bucket = ""
    
    before (done) ->
      (newbucket) <- utils.markedbucket true
      bucket := newbucket
      done!
  
    specify 'should set a key' (done) ->
      err <- commands.setkey bucket, "whatta", "maroon", null
      expect err,err .to.be.null
      done!

    specify 'should fail on bad bucket' (done) ->
      err <- commands.setkey "SOMEKINDABADBUCKET", "whatta", "maroon", null
      expect err .to.equal 'not found'
      done!
  
    describe "only the first #{KEYLENGTH} key chars count. " (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        err <- commands.setkey bucket, basekey + "EXTRASTUFF", 'verlue', null
        expect err,err .to.be.null
        err, value <- commands.getkey bucket, basekey + "E", null
        expect err,err .to.be.null
        expect value .to.equal "verlue"
        done!
  
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        timeout = 0
        timeout = 100 if process.env.NODE_ENV == 'test'
        err <- commands.setkey bucket, basekey + "EJOINDER", 'verlue', null
        <- setTimeout _, timeout
        err <- commands.setkey bucket, basekey + "EYUPNO", 'varloe', null
        <- setTimeout _, timeout
        err <- commands.setkey bucket, basekey + "EYUPYUP", 'verlux', null
        <- setTimeout _, timeout
        expect err,err .to.be.null

        err, value <- commands.getkey bucket, basekey + "EYUPMAN", null
        expect err,err .to.be.null
        expect value .to.equal "verlux"
        done!
  
      specify 'Getting the original base key (one too short) should fail.' (done) ->
        err <- commands.setkey bucket, basekey + "PARSIMONIC", 'verlux', null
        err, value <- commands.getkey bucket, basekey, null
        expect err .to.equal 'not found'
        expect value .to.be.undefined
        done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
      key = "setkey-valuetest"
  
      specify 'Add one to get the full length' (done) ->
        err <- commands.setkey bucket, key, "#{basevalue}E" , null
        err, value <- commands.getkey bucket, key, null
        expect value.length .to.equal VALUELENGTH
        expect value .to.equal "#{basevalue}E"
        expect err, err .to.be.null
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        err <- commands.setkey bucket, key, "#{basevalue}EECHEEWAMAA", null
        err, value <- commands.getkey bucket, key, null
        expect value.length .to.equal VALUELENGTH
        expect value.slice -10 .to.equal 'vvvvvvvvvE'
        expect err, err .to.be.null
        done!

  describe '/newkey' ->
    bucket = ""
    
    before (done) ->
      (newbucket) <- utils.markedbucket true
      bucket := newbucket
      done!
  
    specify 'should create a new key' (done) ->
      err, key <- commands.newkey bucket, "it's some maroon", null
      expect err,err .to.be.null
      console.log key
      expect key .to.match /^[0-9a-zA-Z]{20}$/
      done!

    specify 'should fail on bad bucket' (done) ->
      err, key <- commands.newkey "SOMEKINDABADBUCKET", "nonmaroon", null
      expect err .to.equal 'not found'
      expect key .to.be.undefined
      done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        err, key <- commands.newkey bucket, "#{basevalue}E" , null
        expect key .to.match /^[0-9a-zA-Z]{20}$/
        err, value <- commands.getkey bucket, key, null
        expect value.length .to.equal VALUELENGTH
        expect value .to.equal "#{basevalue}E"
        expect err, err .to.be.null
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        err, key <- commands.newkey bucket, "#{basevalue}EECHEEWAMAA", null
        err, value <- commands.getkey bucket, key, null
        expect value.length .to.equal VALUELENGTH
        expect value.slice -10 .to.equal 'vvvvvvvvvE'
        expect err, err .to.be.null
        done!
  
  describe '/getkey' ->
    bucket = ""
    before (done) ->
      (newbucket) <- utils.markedbucket true
      bucket := newbucket
      <- commands.setkey bucket, "warzoo", "nozoo", null
      <- commands.setkey bucket, "fofrzoo", "rennets", null
      <- commands.setkey bucket, '{"one": "two"}', 'yup', null
      done!
  
    specify 'should get a key' (done) ->
      err, value <- commands.getkey bucket, 'warzoo', null
      expect value .to.equal "nozoo"
      expect err, err .to.be.null
      done!
  
    specify 'should get multiple keys' (done) ->
      err, value <- commands.getkey bucket, '["warzoo","fofrzoo"]', null
      expect value .to.eql do
        warzoo: 'nozoo'
        fofrzoo: 'rennets' 
      expect err, err .to.be.null
      done!
  
    specify 'should get a right key and wrong key' (done) ->
      err, value <- commands.getkey bucket, '["warzoo","xfofrzoo"]', null
      expect value .to.eql do
        warzoo: 'nozoo'
        xfofrzoo: null
      expect err, err .to.be.null
      done!
  
    specify 'should get all wrong keys' (done) ->
      err, value <- commands.getkey bucket, '["parzoo","xfofrzoo"]', null
      expect value .to.be.undefined
      expect err, err .to.equal 'not found'
      done!
  
    specify 'should be ok with "object" key' (done) ->
      err, value <- commands.getkey bucket, '{"one": "two"}', null
      expect value .to.equal "yup"
      expect err, err .to.be.null
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err, value <- commands.getkey "5FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD", 'warzoo', null
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
    specify 'should fail on unknown key' (done) ->
      err, value <- commands.getkey bucket, 'wazoo', null
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
  describe '/delkey' ->
    bucket = ""
  
    before (done) ->
      (newbucket) <- utils.markedbucket true
      bucket := newbucket
      done!

    beforeEach (done) ->
      commands.setkey bucket, "parzoo", "amzoo", null, done
      
    specify 'should delete a key' (done) ->
      err <- commands.delkey bucket, 'parzoo', null
      expect err, err .to.be.null
      # Make sure it's gone.
      err, value <- commands.getkey bucket, 'parzoo', null
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
    specify 'should fail on bad bucket' (done) ->
      err <- commands.delkey '1WKEcUzO2EHlgtqoUzhD', 'parzoo', null
      expect err, err .to.equal 'not found'
      # Make sure it's gone.
      done!
  
    specify 'should fail on unknown key' (done) ->
      err <- commands.delkey bucket, 'lkdsfjlakdfsj', null
      expect err, err .to.equal 'not found'
      done!
      
    describe "only the first #{KEYLENGTH} key chars count" (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", "hamzoo", null
        err <- commands.delkey bucket, "#{basekey}E", null
        expect err, err .to.be.null
        done!
    
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", 'whatta', null
        err <- commands.delkey bucket, "#{basekey}EYUPMAN", null
        expect err, err .to.be.null
        done!
        
      specify 'Deleting the original key (one too short) should fail.' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", 'whatyo', null
        err <- commands.delkey bucket, basekey, null
        expect err, err .to.equal 'not found'
        done!
    
  describe '/listkeys' ->
    bucket = ""
    
    basekey = Array KEYLENGTH .join 'x' # For key length checking
  
    before (done) ->
      @timeout 10000
      newbucket <- utils.markedbucket true
      bucket := newbucket
      <- commands.setkey bucket, "woohoo", "value here", null
      <- commands.setkey bucket, "werp", "value here", null
      <- commands.setkey bucket, "werpawhoo", "value here", null
      <- commands.setkey bucket, "WhoeverKnowsShouldKnow", "value here", null
      <- commands.setkey bucket, "StaggeringlyLessEfficient", "value here", null
      <- commands.setkey bucket, "EatingItStraightOutOfTheBag", "value here", null
      <- commands.setkey bucket, "#{basekey}WHOP", "value here", null
      <- commands.setkey bucket, "#{basekey}WERP", "value here", null # Should get lost...
      <- commands.setkey bucket, "#{basekey}", "value here", null
      <- commands.setkey bucket, "#{basekey.substr 0, KEYLENGTH-4}awho", "value here", null
      <- commands.setkey bucket, "#{basekey.substr 0, KEYLENGTH-3}awho", "value here", null # Should be truncated
      done!
  
    specify 'should list keys' (done) ->
      err, values <- commands.listkeys bucket, null, null
      expect err, 'slk' .to.be.null
      expect values .to.have.members do
        * "testbucketinfo"
          "woohoo"
          "werp",
          "werpawhoo"
          "WhoeverKnowsShouldKnow"
          "StaggeringlyLessEfficient"
          "EatingItStraightOutOfTheBag"
          "#{basekey}W"
          basekey
          "#{basekey.substr 0, KEYLENGTH-4}awho"
          "#{basekey.substr 0, KEYLENGTH-3}awh"
      done!

    specify 'A string can find matching keys, caselessly' (done) ->
      err, values <- commands.listkeys bucket, 'wHo', null
      expect err, 'ascfmkc' .to.be.null
      expect values .to.have.members do
        * "werpawhoo"
          "WhoeverKnowsShouldKnow"
          "#{basekey.substr 0, KEYLENGTH-4}awho"
      done!

    specify 'String with no matches finds nothing.' (done) ->
      err, values <- commands.listkeys bucket, 'wrho', null
      expect err, 'swnmfn' .to.be.null
      expect values .to.have.members []
      done!

    specify 'should list keys of non-existent bucket' (done) ->
      err, values <- commands.listkeys "BARQUET", null, null
      expect err, 'slkoneb' .to.equal 'not found'
      expect values .to.have.undefined
      done!

    specify 'should list keys of empty bucket' (done) ->
      err, emptybucket <- commands.newbucket "Info string", "192.231.221.256", 'slkoeb', null
      err, values <- commands.listkeys emptybucket, null, null
      <- utils.mark_bucket emptybucket
      expect err, 'slkoeb' .to.be.null
      expect values, 'slkoebv' .to.eql []
      done!

  describe '/delbucket' ->
    bucket = ""
  
    beforeEach (done) ->
      (newbucket) <- utils.markedbucket false
      bucket := newbucket
      <- commands.setkey bucket, "junkbucketfufto", 'whatyo', null
      done!
  
    specify 'should delete the bucket' (done) ->
      err <- commands.delkey bucket, "junkbucketfufto", null
      expect err, err .to.be.null
      err <- commands.delbucket bucket, null
      expect err, "second err" .to.be.null  # TODO: UNIFY THESE!!!
      done!
  
    specify 'should fail on unknown bucket' (done) ->
      err <- commands.delkey bucket, "1WKEcUzO2EHlgtqoUzhD", null
      expect err, err .to.equal 'not found'
      done!
  
    specify 'should fail if bucket has entries' (done) ->
      err <- commands.delbucket bucket, null
      expect err, "second err" .to.equal 'not empty'
      # Delete the keys.
      err <- commands.delkey bucket, "junkbucketfufto", null
      expect err, err .to.be.null  # TODO: UNIFY THESE!!!
      # Then try to delete the bucket again.
      err <- commands.delbucket bucket, null
      expect err, "second err" .to.be.null  # TODO: UNIFY THESE!!!
      done!

  describe 'utf-8' ->
    bucket = ""
  
    before (done) ->
      (newbucket) <- utils.markedbucket true
      bucket := newbucket
      done!
      
    #
    # Trim the huge number of UTF cases in development to shorten test
    # runs while still getting some coverage.
    #
    if process.env.NODE_ENV != 'test'
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
          err <- commands.setkey bucket, utf_string, utf_string, null
          expect err, "UCG1 err" .to.be.null
          err, value <- commands.getkey bucket, utf_string, null
          expect err, "UCG2 err" .to.be.null      
          expect value, "value no match" .to.equal utf_string
          done!
  

