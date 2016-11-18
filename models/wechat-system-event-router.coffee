debug = require 'debug'
Cc = require 'change-case'
rest = require 'restler'
moment = require 'moment'
async = require 'async'
config = require '../config'
Agent = require './agent'
Client = require './client'
uuid = require 'node-uuid'
urlParse = require 'url-parse'
jwt = require 'jsonwebtoken'
jwtCfg = require('../config').jwt
io = require('socket.io-emitter')({ host: config.redis.host, port: config.redis.port, key: 'socket.io' })

log = debug 'waas:wechat-router'
class WeChatSystemEventRouter
  handle: (entity,cb) ->
    Agent.findOne where: identifier: entity.agentId.toString(), (camErr,agent) ->
      if camErr
        log 'no wechat app found',camErr
        return cb(null,'')     
      evt = Cc.lowerCase entity.event
      # system login
      if evt == 'scancode_waitmsg' and entity.scanCodeInfo?[0]?.ScanType == 'qrcode'
        key = entity.scanCodeInfo[0].ScanResult
        async.waterfall [
          (acb) ->
            jwt.verify key, jwtCfg.login.secret, (jwterr, loginCode) ->
              if loginCode
                if loginCode.type == 'login' then acb(null,loginCode) else acb('非登录二维码')
                acb(null,loginCode)
              else if jwterr?.name == 'TokenExpiredError'
                acb('二维码过期')
              else
                acb('非法的二维码')
          (payload,acb) ->
            log "canned paylod",payload
            Client.findOne where: identifier: payload.clientId, (gerr,client) ->
              if client
                payload.secret = client.secret
                payload.redirectUri = client.redirectUri unless payload.redirectUri? and /https?:\/\/.+/.test(payload.redirectUri)
                url = urlParse(payload.redirectUri,true)
                url.query.info = payload.info if payload.info
                if url.hostname in ['127.0.0.1','localhost',urlParse(client.redirectUri,true).hostname]
                  payload.redirectUri = url.toString()
                  acb(null,payload)
                else
                  acb('client使用了未注册的回调域')
              else
                acb('非法的client')
          (payload,acb) ->
            agent.fetchAccessToken (err,token) -> acb(null,payload)
          (payload,acb) ->
            agent.user { id: entity.fromUser }, (uerr,user) ->
              if uerr
                log "no such user #{entity.fromUser}",uerr
                acb "no such user #{entity.fromUser}"
              else
                payload.user =
                  id: user.id
                  name: user.name
                  email: user.email
                  mobile: user.mobile
                acb(null,payload)
        ], (asyncErr,payload) ->
          if payload
            payload.user.type = 'ticket'
            ticket = jwt.sign payload.user, payload.secret,jwtCfg.ticket.options
            payload.user.type = 'session'
            sessionToken = jwt.sign payload.user,jwtCfg.session.secret,jwtCfg.session.options
            url = urlParse(payload.redirectUri,true)
            url.query.ticket = ticket
            io.to(key).emit 'qrcode_scan',
                        state: 'success'
                        ticket: ticket
                        redirectUri: url.toString()
                        session: sessionToken
            cb(null,"Welcome, #{payload.user.name}!")
          else
            io.to(key).emit 'qrcode_scan',state: 'fail',message: asyncErr
            cb(null,'')
      else 
        cb null,''

module.exports = WeChatSystemEventRouter