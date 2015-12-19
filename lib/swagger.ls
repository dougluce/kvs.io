require! {
  './common': {errors}
}

export swagger = 
  * swagger: "2.0"
    info:
      title: "The kvs.io API",
      description: """
# A simple, reliable, and fast key-value store.

The kvs.io service provides a globally accessible key-value store
organized into buckets and stored redundantly.

This service lets you store data securely using only browser-based
HTML without the need for any complex set-up.

The first principle of kvs.io is simplicity. The regular API gives you
all the semantic power of REST. The simple API lets you stuff
parameters into the URL for a normal HTTP GET or send them as form
data with a POST.  All calls may be made via HTTP or HTTPS (use of
HTTPS is STRONGLY recommended).

The second principle of kvs.io is reliability.  Redundant front-ends
keep availability high.  Each key-value pair is stored on at least
three separate back-end servers.

The third princple of kvs.io is speed.  A single, simple HTTP
transaction is all it takes.  Your bucket name is your key to the
system, and there is no need to go through an authentication
transaction.  One hit in, one response out.

kvs.io supports two broad styles of interaction.  The RESTful
interface provides varying methods acting on resources in the usual
REST way.  The simple interface lets you build your application using
only GET or POST directives and simple URL or form body based data
exchanges.  You may use any combination of any of these methods as is
necessary to support your application.

""",
      version: "0.1"
    consumes: ["text/plain; charset=utf-8", "application/json"]
    produces: ["text/plain; charset=utf-8", "application/json"]
    basePath: "/"
    paths: {}


# Template for a single operation.
#
# Encompasses both REST and simple forms.
#
# Simple form is all URL based

export swaggerOperation = (commandname, cmd) ->
  path = commandname
  restPath = []
  getParams = []
  postParams = []
  restParams = []
  restPath.push cmd.restpath if cmd.restpath
  for cmdparam in cmd.params
    continue if cmdparam['x-private']
    param = {} <<<< cmdparam
    path += "/{#{param.name}}" if param.in not in ['query']
    restPath.push "{#{param.name}}" if param.required and param.in not in ['query', 'body']

    restParam = {} <<<< param
    if not param.in
      restParam <<< 
        in: if param.required then 'path' else 'query'
        type: 'string'
    restParams.push restParam
    delete param.schema

    getParams.push ({} <<<< param) <<< do
      in: if param.in == 'query' then 'query' else 'path'
      type: 'string'

    postParams.push ({} <<<< param) <<< do
      in: 'formData'
      type: 'string'

  operation = 
    * summary: cmd.summary
      description: cmd.description
      responses:
        "#{cmd.success}":
          description: "Successful request."
        500:
          description: "Internal server error."

  for error in cmd.errors
    operation.responses <<<
       "#{new errors[error][0]!statusCode}":
         description: errors[error][1]

  getOp = ({} <<<< operation) <<<
    tags: ["simple:#{cmd.group}"]
    operationId: "get#commandname"
  getOp.parameters = getParams if getParams.length > 0

  postOp = ({} <<<< operation) <<<
    tags: ["simple:#{cmd.group}"]
    operationId: "post#commandname"
  postOp.parameters = postParams if postParams.length > 0

  swagger.paths.{}"/#path".get = getOp
  swagger.paths.{}"/#commandname".post = postOp

  if cmd.rest
    restOp = ({} <<<< operation) <<<
      tags: ["rest:#{cmd.group}"]
      operationId: "rest#commandname"
    restOp.parameters = restParams if restParams.length > 0
    restPath = '/' + restPath.join '/'
    method = cmd.rest[0]
    method = 'delete' if method == 'del'
    swagger.paths.{}"#restPath".[method] = restOp

