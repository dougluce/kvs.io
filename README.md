# kvsio

Kvs.io provides a monitorable key-value store organized into buckets
and stored redundantly.  The system stores data securely using only
browser-based HTML without the need for any complex set-up.

## Principles

### Simplicity

The regular API gives you all the semantic power of REST. The simple
API lets you stuff parameters into the URL for a normal HTTP GET or
send them as form data with a POST. All calls may be made via HTTP or
HTTPS (use of HTTPS is STRONGLY recommended).

### Reliability

Redundant front-ends keep availability high.  Via Riak, each key-value
pair is stored on at least three separate back-end servers.

### Speed

The third principle of kvs.io is speed.  A single, simple HTTP
transaction is all it takes.  Buckets organize all data on the system.
There is no need to go through an authentication transaction.  One hit
in, one response out.

## Using kvs.io

kvs.io supports two broad styles of interaction. The RESTful interface
provides varying methods acting on resources in the usual REST
way. The simple interface lets you build your application using only
GET or POST directives and simple URL or form body based data
exchanges. You may use any combination of any of these methods as is
necessary to support your application.

kvs.io also provides key-watching capabilities. Store and retrieve
data centrally with simple REST calls.  Use websockets or long polling
to monitor key values for changes.

Buckets are cryptographically secure random strings of data.  To
access data, you must know the bucket name.

### Create a new bucket

    % curl --request POST https://localhost:8080/
    "E3WjhOwvDD1gfP28I0t1"

### Set a key with PUT

   % curl --data 'Conrad Aiken' --request PUT https://localhost:8080/E3WjhOwvDD1gfP28I0t1/name

### Set a key with POST parameters

    % curl --request POST --data 'bucket=E3WjhOwvDD1gfP28I0t1&key=address&value=228 East Oglethorpe Avenue Savannah, Georgia 31401' https://localhost:8080/setkey

### Retrieve

    % curl -sg 'https://localhost:8080/getkey/E3WjhOwvDD1gfP28I0t1/["name","address"]' | jq .
    {
      "name": "Conrad Aiken",
      "address": "228 East Oglethorpe Avenue Savannah, Georgia 31401"
    }

### Listen to changes

To monitor changes within a bucket, open a Websocket connection to your server:
`ws://localhost:8080/ws` for instance.  Issue this command:

```json
{
    "command": "listen",
    "bucket": "BUCKETNAME"
}

```

Set a key in the bucket.  On the listen interface, you'll see messages like:

```json
{
  "bucket": "BUCKETNAME",
  "event": "setkey",
  "args": [
    "mykey",
    "myvalue"
    ""
  ]
}

```

You can also listen to bucket events using long polling instead of
websockets.

## Installation

    npm install kvsio

For production use, kvsio requires [riak](http://docs.basho.com/riak/latest/).

## Running

## Development

Run tests with:

    npm test

kvs.io leans on the distributed nature of Riak in order to serve data
from multiple machines.  If you run this on a cluster and the cluster
machines can get to each other on port 80, the monitoring functions
will work across the cluster.
