require! {
  chai: {expect}
  sinon
  './utils'
  './utf-cases'
  '../lib/commands'
  crypto
  async
}

KEYLENGTH = 256 # Significant length of keys.
VALUELENGTH = 65536 # Significant length of values

sandbox = null

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
      user, err, newbucket <- commands.newbucket "Info string", "192.231.221.256", "scab test", null
      expect user, "newbucket user" .to.equal newbucket
      expect err, "newbucket #err" .to.be.null
      expect newbucket .to.match /^[0-9a-zA-Z]{20}$/
      <- utils.mark_bucket newbucket
      done!
  
    specify 'crypto error on bucket creation' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb "Crypto error"
      user, err, newbucket <- commands.newbucket  "Info string", "192.231.221.257", "ceobc test", null
      expect user,"newbucket cryptoerror" .to.be.null
      expect err .to.equal 'Crypto error'
      expect newbucket .to.be.undefined
      done!
  
    specify 'Bad bucket creation error' sinon.test (done) ->
      @stub crypto, "randomBytes", (count, cb) ->
        cb null, "INEXPLICABLYSAMERANDOMDATA"
      user, err, newbucket <- commands.newbucket  "Info string", "192.231.221.257", 'bbce test', null
      expect user,"bbce" .to.equal newbucket
      expect err .to.equal null
      expect newbucket .to.equal "INEXPLICABLYSAMERANDOMDATA"
      
      user, err, newbucket <- commands.newbucket  "Info string", "192.231.221.257", 'bbce test 2', null
      expect user,"bbce2" .to.equal newbucket
      expect err, err .to.equal 'bucket already exists'
      expect newbucket .to.equal "INEXPLICABLYSAMERANDOMDATA"
      done!
  
  describe '/setkey' ->
    bucket = ""
    
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!
  
    specify 'should set a key' (done) ->
      user, err <- commands.setkey bucket, "whatta", "maroon", null
      expect user, 'ssak2' .to.equal bucket
      expect err,'ssak' .to.be.null
      done!

    specify 'should fail on bad bucket' (done) ->
      user, err <- commands.setkey "SOMEKINDABADBUCKET", "whatta", "maroon", null
      expect user, 'sfabb2' .to.equal "SOMEKINDABADBUCKET"
      expect err, 'sfabb' .to.equal 'not found'
      done!
  
    describe "only the first #{KEYLENGTH} key chars count. " (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        user, err <- commands.setkey bucket, basekey + "EXTRASTUFF", 'verlue', null
        expect user, 'aotgtfl' .to.equal bucket
        expect err,'aotgtfl2' .to.be.null
        user, err, value <- commands.getkey bucket, basekey + "E", null
        expect user, 'aotgtfl3' .to.equal bucket
        expect err,'aotgtfl3' .to.be.null
        expect value .to.equal "verlue"
        done!
  
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        timeout = 0
        timeout = 100 if process.env.NODE_ENV == 'test'
        user, err <- commands.setkey bucket, basekey + "EJOINDER", 'verlue', null
        <- setTimeout _, timeout
        user, err <- commands.setkey bucket, basekey + "EYUPNO", 'varloe', null
        <- setTimeout _, timeout
        user, err <- commands.setkey bucket, basekey + "EYUPYUP", 'verlux', null
        <- setTimeout _, timeout
        expect err,err .to.be.null

        user, err, value <- commands.getkey bucket, basekey + "EYUPMAN", null
        expect user, 'aabbotfigtc' .to.equal bucket
        expect err, 'aabbotfigtc2' .to.be.null
        expect value .to.equal "verlux"
        done!
  
      specify 'Getting the original base key (one too short) should fail.' (done) ->
        user, err <- commands.setkey bucket, basekey + "PARSIMONIC", 'verlux', null
        user, err, value <- commands.getkey bucket, basekey, null
        expect user, 'gtobkotssf' .to.equal bucket
        expect err, 'gtobkotssf2' .to.equal 'not found'
        expect value .to.be.undefined
        done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
      key = "setkey-valuetest"
  
      specify 'Add one to get the full length' (done) ->
        user, err <- commands.setkey bucket, key, "#{basevalue}E" , null
        user, err, value <- commands.getkey bucket, key, null
        expect user, 'aotgtfl' .to.equal bucket
        expect err, 'aotgtfl2' .to.be.null
        expect value.length .to.equal VALUELENGTH
        expect value .to.equal "#{basevalue}E"
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        user, err <- commands.setkey bucket, key, "#{basevalue}EECHEEWAMAA", null
        user, err, value <- commands.getkey bucket, key, null
        expect user, 'vtligc' .to.equal bucket
        expect err, 'vtligc2' .to.be.null
        expect value.length .to.equal VALUELENGTH
        expect value.slice -10 .to.equal 'vvvvvvvvvE'
        done!

  describe '/newkey' ->
    bucket = ""
    
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!
  
    specify 'should create a new key' (done) ->
      user, err, key <- commands.newkey bucket, "it's some maroon", null
      expect user, 'scank' .to.equal bucket
      expect err, 'scank2' .to.be.null
      expect key .to.match /^[0-9a-zA-Z]{20}$/
      done!

    specify 'should fail on bad bucket' (done) ->
      user, err, key <- commands.newkey "SOMEKINDABADBUCKET", "nonmaroon", null
      expect user .to.equal "SOMEKINDABADBUCKET"
      expect err .to.equal 'not found'
      expect key .to.be.undefined
      done!
  
    describe "only the first #{VALUELENGTH} value chars count." (done) ->
      basevalue = Array VALUELENGTH .join 'v' # VALUELENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        user, err, key <- commands.newkey bucket, "#{basevalue}E" , null
        expect user .to.equal bucket
        expect key .to.match /^[0-9a-zA-Z]{20}$/
        user, err, value <- commands.getkey bucket, key, null
        expect user .to.equal bucket
        expect value.length .to.equal VALUELENGTH
        expect value .to.equal "#{basevalue}E"
        expect err, err .to.be.null
        done!
  
      specify 'Value too long?  It gets chopped.' (done) ->
        user, err, key <- commands.newkey bucket, "#{basevalue}EECHEEWAMAA", null
        user, err, value <- commands.getkey bucket, key, null
        expect user .to.equal bucket
        expect value.length .to.equal VALUELENGTH
        expect value.slice -10 .to.equal 'vvvvvvvvvE'
        expect err, err .to.be.null
        done!
  
  describe '/getkey' ->
    bucket = ""
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      <- commands.setkey bucket, "warzoo", "nozoo", null
      <- commands.setkey bucket, "fofrzoo", "rennets", null
      <- commands.setkey bucket, '{"one": "two"}', 'yup', null
      done!
  
    specify 'should get a key' (done) ->
      user, err, value <- commands.getkey bucket, 'warzoo', null
      expect user .to.equal bucket
      expect value .to.equal "nozoo"
      expect err, err .to.be.null
      done!
  
    specify 'should get multiple keys' (done) ->
      user, err, value <- commands.getkey bucket, '["warzoo","fofrzoo"]', null
      expect user .to.equal bucket
      expect value .to.eql do
        warzoo: 'nozoo'
        fofrzoo: 'rennets' 
      expect err, err .to.be.null
      done!
  
    specify 'should get a right key and wrong key' (done) ->
      user, err, value <- commands.getkey bucket, '["warzoo","xfofrzoo"]', null
      expect user .to.equal bucket
      expect value .to.eql do
        warzoo: 'nozoo'
        xfofrzoo: null
      expect err, err .to.be.null
      done!
  
    specify 'should get all wrong keys' (done) ->
      user, err, value <- commands.getkey bucket, '["parzoo","xfofrzoo"]', null
      expect user .to.equal bucket
      expect value .to.be.undefined
      expect err, err .to.equal 'not found'
      done!
  
    specify 'should be ok with "object" key' (done) ->
      user, err, value <- commands.getkey bucket, '{"one": "two"}', null
      expect user .to.equal bucket
      expect value .to.equal "yup"
      expect err, err .to.be.null
      done!
  
    specify 'should fail on bad bucket' (done) ->
      user, err, value <- commands.getkey "5FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD", 'warzoo', null
      expect user .to.equal "5FBrtQyw19S2jM9PQjhe1WKEcUzO2EHlgtqoUzhD"
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
    specify 'should fail on unknown key' (done) ->
      user, err, value <- commands.getkey bucket, 'wazoo', null
      expect user .to.equal bucket
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
  describe '/delkey' ->
    bucket = ""
  
    before (done) ->
      newbucket <- utils.markedbucket true
      bucket := newbucket
      done!

    beforeEach (done) ->
      user, err <- commands.setkey bucket, "parzoo", "amzoo", null
      expect user .to.equal bucket
      done err
      
    specify 'should delete a key' (done) ->
      user, err <- commands.delkey bucket, 'parzoo', null
      expect user .to.equal bucket
      expect err, err .to.be.null
      # Make sure it's gone.
      user, err, value <- commands.getkey bucket, 'parzoo', null
      expect user .to.equal bucket
      expect err .to.equal 'not found'
      expect value .to.be.undefined
      done!
  
    specify 'should fail on bad bucket' (done) ->
      user, err <- commands.delkey '1WKEcUzO2EHlgtqoUzhD', 'parzoo', null
      expect user .to.equal '1WKEcUzO2EHlgtqoUzhD'
      expect err, err .to.equal 'not found'
      # Make sure it's gone.
      done!
  
    specify 'should fail on unknown key' (done) ->
      user, err <- commands.delkey bucket, 'lkdsfjlakdfsj', null
      expect user .to.equal bucket
      expect err, err .to.equal 'not found'
      done!
      
    describe "only the first #{KEYLENGTH} key chars count" (done) ->
      basekey = Array KEYLENGTH .join 'x' # KEYLENGTH-1 length string
  
      specify 'Add one to get the full length' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", "hamzoo", null
        user, err <- commands.delkey bucket, "#{basekey}E", null
        expect user .to.equal bucket
        expect err, err .to.be.null
        done!
    
      specify 'Add a bunch, but only the first is going to count.' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", 'whatta', null
        user, err <- commands.delkey bucket, "#{basekey}EYUPMAN", null
        expect user .to.equal bucket
        expect err, err .to.be.null
        done!
        
      specify 'Deleting the original key (one too short) should fail.' (done) ->
        <- commands.setkey bucket, basekey + "EXTRASTUFF", 'whatyo', null
        user, err <- commands.delkey bucket, basekey, null
        expect user .to.equal bucket
        expect err, err .to.equal 'not found'
        done!
    
  describe '/listkeys' ->
    bucket = ""
    
    basekey = Array KEYLENGTH .join 'x' # For key length checking
  
    before (done) ->
      @timeout 10000
      newbucket <- utils.markedbucket true
      bucket := newbucket
      kv_pairs = 
        * "woohoo", "value here"
        * "werp", "value here"
        * "werpawhoo", "value here"
        * "WhoeverKnowsShouldKnow", "value here"
        * "StaggeringlyLessEfficient", "value here"
        * "EatingItStraightOutOfTheBag", "value here"
        * "#{basekey}WHOP", "value here"
        * "#{basekey}WERP", "value here" # Should get lost...
        * "#{basekey}", "value here"
        * "#{basekey.substr 0, KEYLENGTH-4}awho", "value here"
        * "#{basekey.substr 0, KEYLENGTH-3}awho", "value here" # Should be truncated
      <- async.each kv_pairs, (keyvalue, cb) ->
        commands.setkey bucket, keyvalue[0], keyvalue[1], null, cb
      done!
  
    specify 'should list keys' (done) ->
      user, err, values <- commands.listkeys bucket, null, null
      expect user .to.equal bucket
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
      user, err, values <- commands.listkeys bucket, 'wHo', null
      expect user .to.equal bucket
      expect err, 'ascfmkc' .to.be.null
      expect values .to.have.members do
        * "werpawhoo"
          "WhoeverKnowsShouldKnow"
          "#{basekey.substr 0, KEYLENGTH-4}awho"
      done!

    specify 'String with no matches finds nothing.' (done) ->
      user, err, values <- commands.listkeys bucket, 'wrho', null
      expect user .to.equal bucket
      expect err, 'swnmfn' .to.be.null
      expect values .to.have.members []
      done!

    specify 'should list keys of non-existent bucket' (done) ->
      user, err, values <- commands.listkeys "BARQUET", null, null
      expect user .to.equal 'BARQUET'
      expect err, 'slkoneb' .to.equal 'not found'
      expect values .to.have.undefined
      done!

    specify 'should list keys of empty bucket' (done) ->
      user, err, emptybucket <- commands.newbucket "Info string", "192.231.221.256", 'slkoeb', null
      user, err, values <- commands.listkeys emptybucket, null, null
      <- utils.mark_bucket emptybucket
      expect user .to.equal emptybucket
      expect err, 'slkoeb' .to.be.null
      expect values, 'slkoebv' .to.eql []
      done!

  describe '/delbucket' ->
    bucket = ""
  
    beforeEach (done) ->
      newbucket <- utils.markedbucket false
      bucket := newbucket
      <- commands.setkey bucket, "junkbucketfufto", 'whatyo', null
      done!
  
    specify 'should delete the bucket' (done) ->
      user, err <- commands.delkey bucket, "junkbucketfufto", null
      expect user .to.equal bucket
      expect err, err .to.be.null
      user, err <- commands.delbucket bucket, null
      expect user .to.equal bucket
      expect err, "second err" .to.be.null  # TODO: UNIFY THESE!!!
      done!
  
    specify 'should fail on unknown bucket' (done) ->
      user, err <- commands.delkey bucket, "1WKEcUzO2EHlgtqoUzhD", null
      expect user .to.equal bucket
      expect err, err .to.equal 'not found'
      done!
  
    specify 'should fail if bucket has entries' (done) ->
      user, err <- commands.delbucket bucket, null
      expect user .to.equal bucket
      expect err, "second err" .to.equal 'not empty'
      # Delete the keys.
      user, err <- commands.delkey bucket, "junkbucketfufto", null
      expect user .to.equal bucket
      expect err, err .to.be.null  # TODO: UNIFY THESE!!!
      # Then try to delete the bucket again.
      user, err <- commands.delbucket bucket, null
      expect user .to.equal bucket
      expect err, "second err" .to.be.null  # TODO: UNIFY THESE!!!
      done!

  describe 'utf-8' ->
    bucket = ""
  
    before (done) ->
      newbucket <- utils.markedbucket true
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
          user, err <- commands.setkey bucket, utf_string, utf_string, null
          expect user .to.equal bucket
          expect err, "UCG1 err" .to.be.null
          user, err, value <- commands.getkey bucket, utf_string, null
          expect user .to.equal bucket
          expect err, "UCG2 err" .to.be.null      
          expect value, "value no match" .to.equal utf_string
          done!
  
