express = require 'express'
debug = require 'debug'
uuid = require 'node-uuid'
moment = require 'moment'
urlParse = require 'url-parse'
config = require '../config'
Client = require '../models/client'
Agent = require '../models/agent'
ss = require '../models/socket-server'
jwtCfg = require('../config').jwt.accessToken
jwt = require 'jsonwebtoken'
async = require 'async'
authorization = require '../models/authorization'

router = express.Router()
log = debug('http')

router.use authorization.browserAuth()

router.get '/', (req,res) ->
  res.redirect '/tokens/verify'

router.get '/verify', (req, res) ->
  res.render 'tokens/verify'

router.post '/verify', (req,res) ->
  async.waterfall [
    (cb) ->
      if req.body.accessToken
        jwt.verify req.body.accessToken, jwtCfg.secret, (jwterr, payload) ->
          if payload?.type == 'accessToken' and payload?.agentId?
            log payload
            cb(null,payload)
          else if jwterr?.name == 'TokenExpiredError'
            cb 'Access token过期'
          else
            cb '非法的access token'
      else
        cb '无待验证的token'
    (info,cb) ->
      Agent.findOne where: identifier: info.agentId.toString(), (camErr,agent) ->
        unless agent
          cb '无对应的app'
        else
          info.agent = agent
          cb null,info
    (info,cb) ->
      Client.findOne where: identifier: info.clientId.toString(), (camErr,client) ->
        unless client
          cb '无对应的client'
        else
          info.client = client
          cb null,info
  ], (err,info) ->
    if err
      res.status(400).json message: err
    else
      res.json info

module.exports = router            
