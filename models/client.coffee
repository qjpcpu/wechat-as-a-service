database = require './database'
debug = require 'debug'
uuid = require 'node-uuid'
jwtCfg = require('../config').jwt.accessToken
jwt = require 'jsonwebtoken'
log = debug 'waas:client'

Client = database.define 'Client',
  {
    name: { type: database.String,index: true }
    identifier: { type: database.String,index: true }
    secret: { type: database.String,index: true }
    agentIdentifier: { type: database.String,index: true }
    redirectUri: type: database.String
  }

# middlewares
Client.beforeSave = (next) ->
  this.identifier = (new Buffer(uuid.v1())).toString() unless this.identifier?.length > 0
  this.secret = (new Buffer(uuid.v1())).toString('base64')[0..14] unless this.secret?.length > 0
  log this
  next()

Client.prototype.generateAccessToken =  ->
  payload = 
    type: 'accessToken'
    clientId: this.identifier
    agentId: this.agentIdentifier
  jwt.sign payload, jwtCfg.secret,jwtCfg.options

module.exports = Client