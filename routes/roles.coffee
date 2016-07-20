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

router.get '/', (req, res) ->
  agent = res.locals.agent
  agent.tags (err,list) ->
    if err
      log "failed to get roles",err
      res.json  []
    else
      regex = new RegExp "^#{res.locals.agent.identifier}_"
      list = (
        for r in list when regex.test(r.name)
          r.name = r.name.replace(regex,'')
          r
      )
      res.json list

router.post '/', (req,res) ->
  agent = res.locals.agent
  unless req.body.name
    log "cannt found role name"
    return res.status(403).json message: "cannot find role name"
  req.body.name = "#{res.locals.agent.identifier}_#{req.body.name}"
  agent.createTag { name: req.body.name },(err,role) ->
    if err
      res.status(403).json message: err
    else
      regex = new RegExp "^#{res.locals.agent.identifier}_"
      role.name = role.name.replace regex,''
      res.json role

router.delete '/:id', (req,res) ->
  agent = res.locals.agent
  agent.deleteTag { id: req.params.id },(err,role) ->
    if err
      res.status(403).json message: err
    else
      res.json message: 'OK'

router.get '/:id/users', (req, res) ->
  agent = res.locals.agent
  agent.usersByTag { id: req.params.id }, (err,list) ->
    if err
      log 'failed to get users',err
      res.status(403).json message: err
    else
      res.json list

router.post '/:id/attach', (req, res) ->
  agent = res.locals.agent
  unless req.body.users
    return res.status(403).json message: 'no user found'
  agent.attachTag { tagId: req.params.id,users: req.body.users }, (err) ->
    if err
      log 'failed to attach role to user',err
      res.status(403).json message: err
    else
      res.json message: 'OK'

router.post '/:id/detach', (req, res) ->
  agent = res.locals.agent
  unless req.body.users
    return res.status(403).json message: 'no user found'
  agent.detachTag { tagId: req.params.id,users: req.body.users }, (err) ->
    if err
      log 'failed to attach role to user',err
      res.status(403).json message: err
    else
      res.json message: 'OK'        

router.post '/:name/send', (req, res) ->
  agent = res.locals.agent
  agent.tags (err,list) ->
    req.body.tagIds ?= []
    if err
      log "failed to get roles",err
      res.status(404).json message: "no such role:#{req.params.name}"
      return
    else
      regex = new RegExp "^#{res.locals.agent.identifier}_"
      list = (
        for r in list when r.name == "#{res.locals.agent.identifier}_#{req.params.name}"
          r.name = r.name.replace(regex,'')
          r
      )
      if list.length == 0
        res.status(404).json message: "no such role:#{req.params.name}"
        return
      else
        req.body.tagIds.push list[0].id

    req.body.type ?= 'text'
    unless req.body.type in ['text','news']
      log "Not supported message type #{req.body.type}"
      return res.status(403).json message: "Not supported message type #{req.body.type}"
    unless req.body.body
      log 'message body not found',req.body
      return res.status(403).json message: 'message body not found'
    agent.sendMessage req.body, (err) ->
      if err
        log "send message failed",err
        res.status(403).json message: err
      else
        res.json message: 'OK'       

module.exports = router            
