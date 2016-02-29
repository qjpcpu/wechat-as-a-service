express = require 'express'
debug = require 'debug'
uuid = require 'node-uuid'
moment = require 'moment'
urlParse = require 'url-parse'
config = require '../config'
Client = require '../models/client'
ss = require '../models/socket-server'
jwtCfg = require('../config').jwt.accessToken
jwt = require 'jsonwebtoken'

router = express.Router()
log = debug('http')

router.get '/', (req, res) ->
  if req.session.currentUser
    res.redirect '/clients'
  else
    Client.findOne where: name: 'self',(err,client) ->
      if client?
        locals = clientId: client.identifier
      else
        locals = {}
      if req.query.error
        locals.error = new Buffer(req.query.error, 'base64').toString('utf8')
      res.render 'index',locals

router.get '/local_talk',(req,res) ->
  additionalHeaders = 
    'Access-Control-Allow-Origin':  '*'
    'Access-Control-Allow-Methods': 'GET,PUT,POST,DELETE'
    'Access-Control-Allow-Headers': 'X-Requested-With'
    'Content-Security-Policy':      "default-src 'unsafe-inline' *"
    'X-Content-Security-Policy':    "default-src 'unsafe-inline' *"
    'X-WebKit-CSP':                 "default-src 'unsafe-inline' *"
  res.setHeader hname,hvalue for hname,hvalue of additionalHeaders
  res.render 'local_talk'

router.get '/check_login', (req,res) ->
  if req.session.currentUser
    res.redirect '/clients'
    return
  unless req.query.ticket
    res.redirect "/?error=#{new Buffer('无登录凭据').toString('base64')}"
    return
  Client.findOne where: name: 'self',(err,client) ->
    if client
      jwt.verify req.query.ticket, client.secret, (jwterr, user) ->
        if user
          if user.id in config.administrators
            req.session.currentUser = user.id
            res.redirect '/clients'
          else
            log "#{user.id}不在管理员组"
            errMsg = new Buffer("#{user.name}不在管理员组").toString('base64')
            res.redirect "/?error=#{errMsg}"
        else
          log 'ticket校验失败'
          errMsg = new Buffer('凭据校验失败').toString('base64')
          res.redirect "/?error=#{errMsg}"
    else
      log '无此client'
      errMsg = new Buffer('无默认登录配置').toString('base64')
      res.redirect "/?error=#{errMsg}"

router.post '/validate', (req,res) ->
  secret = req.body.secret
  unless secret 
    log "No secret found in request"
    res.status(403).json message: 'no secret found'
    return
  ticket = req.body.ticket
  unless ticket
    log "No ticket found in request"
    res.status(403).json message: 'no ticket found'
    return    
  Client.findOne where: secret: secret, (terr,client) ->
    unless client
      log "fetch secret config failed",terr
      res.status(403).json message: 'no valid secret'
    else      
      jwt.verify ticket, secret, (jwterr, user) ->
        if user
          res.json user
        else if jwterr?.name == 'TokenExpiredError'
          res.status(403).json message: 'ticket已过期'
        else
          res.status(403).json message: '非法的ticket'

router.post '/exchange_token', (req,res) ->
  secret = req.post.secret
  unless secret 
    log "No secret found in request"
    res.status(403).json message: 'no secret found'
    return
  Client.findOne where: secret: secret,(err,client) ->
    if err
      log "fetch access token config failed",err
      res.status(403).json message: 'no valid secret'
    else
      accessToken = client.generateAccessToken()
      res.json { message: 'update token ok',token: accessToken }
     

module.exports = router
