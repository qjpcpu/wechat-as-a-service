async = require 'async'
express = require 'express'
debug = require 'debug'
merge = require 'merge'
Agent = require '../models/agent'
Client = require '../models/client'
jwtCfg = require('../config').jwt.accessToken
jwt = require 'jsonwebtoken'

router = express.Router()
log = debug 'http'

router.use  (req,res,next) ->
  token = req.query.accessToken
  unless token 
    log "No accessToken found in request"
    res.status(403).json message: 'no access token found'
    return
  jwt.verify token, jwtCfg.secret, (jwterr, payload) ->
    if payload?.type == 'accessToken' and payload?.agentId?
      Agent.findOne where: identifier: payload.agentId.toString(), (camErr,agent) ->
        if camErr
          log "not found app",err
          res.status(404).json message: '无对应的app' 
        else
          agent.fetchAccessToken (tokenErr,nToken) ->
            res.locals.accessToken = nToken
            res.locals.agent = agent
            next()
    else if jwterr?.name == 'TokenExpiredError'
      res.status(403).json message: 'Access token过期'
    else
      res.status(403).json message: '非法的access token'
      
# query:
# departmentId: default=1
# detail: show detail,default=false
# recursive: fetch chidren,default=yes|true
# status: all/watched/disabled/unwatched, default: watched
router.get '/', (req, res) ->
  agent = res.locals.agent
  opts = 
    departmentId: req.query.departmentId
    detail: (req.query.detail in ['yes','true'])
    recursive: (req.query.recursive in [undefined,'yes','true'])
    status: req.query.status
  agent.users opts,(err,list) ->
    if err
      log "failed to get users",err
      res.json  []
    else
      res.json list

router.post '/', (req,res) ->
  user = req.body
  async.waterfall [
    ((callback) ->
      if user.email
        user.id = user.email.replace /@.*/,'' unless user.id
        callback() 
      else 
        callback('No user email')
    )   
  ],(err) ->
    if err
      log 'failed to create user',err
      res.status(403).json message: err
    else
      log "create user: #{user}"
      agent = res.locals.agent
      agent.createUser user, (err1) ->
        if err1
          log 'failed to create user',err1
          res.status(403).json message: err1
        else
          res.json message: 'OK'


router.post '/send', (req,res) ->
  log req.body
  agent = res.locals.agent
  req.body.type ?= 'text'
  unless req.body.type in ['text','news']
    log "Not supported message type #{req.body.type}"
    return res.status(403).json message: "Not supported message type #{req.body.type}"
  unless req.body.body
    log 'message body not found',req.body
    return res.status(403).json message: 'message body not found'
  if (not req.body.users) and (not req.body.tagIds) and (not req.body.departmentIds)
    log "tagId/users/departmentIds not found"
    return res.status(403).json message: 'tagIds/users/departmentIds not found'
  agent.sendMessage req.body, (err) ->
    if err
      log "send message failed",err
      res.status(403).json message: err
    else
      res.json message: 'OK' 

router.get '/:userId', (req,res) ->
  agent = res.locals.agent
  agent.user { id: req.params.userId}, (err,user) ->
    if err
      log "no such user #{req.params.userId}",err
      res.status(404).json message: "no such user #{req.params.userId}"
    else
      res.json user  

router.put '/:userId', (req,res) ->
  agent = res.locals.agent
  user = merge req.body,{id: req.params.userId}
  agent.updateUser user, (err) ->
    if err
      log "no such user #{req.params.userId}",err
      res.status(404).json message: "no such user #{req.params.userId}"
    else
      res.json message: 'OK'  

router.get '/:userId/invite', (req,res) ->
  agent = res.locals.agent
  agent.inviteUser {id: req.params.userId}, (err) ->
    if err
      log "cannt invite user #{req.params.userId}",err
      res.status(403).json message: err
    else
      res.json message: 'OK' 

router.delete '/:userId', (req,res) ->
  agent = res.locals.agent
  agent.deleteUser {id: req.params.userId}, (err) ->
    if err
      log "can not del user #{req.params.userId}",err
      res.status(404).json message: err
    else
      res.json message: 'OK'

# opts:
# type: 消息类型,default to text
# users/tagIds/departmentIds(Array/String)(Optional)
# body(object/Array/string)
router.post '/:userId/send', (req,res) ->
  agent = res.locals.agent
  req.body.type ?= 'text'
  unless req.body.type in ['text','news']
    log "Not supported message type #{req.body.type}"
    return res.status(403).json message: "Not supported message type #{req.body.type}"
  unless req.body.body
    log 'message body not found',req.body
    return res.status(403).json message: 'message body not found'
  req.body.users = [req.params.userId]
  if (not req.body.users) and (not req.body.tagIds) and (not req.body.departmentIds)
    log "tagId/users/departmentIds not found"
    return res.status(403).json message: 'tagId/users/departmentIds not found'
  agent.sendMessage req.body, (err) ->
    if err
      log "send message failed",err
      res.status(403).json message: err
    else
      res.json message: 'OK'      


module.exports = router            