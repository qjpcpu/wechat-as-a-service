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
  agent.departments { id: req.query.id },(err,list) ->
    if err
      log "failed to get departments",err
      res.json  []
    else
      res.json list

router.post '/', (req, res) ->
  unless req.body.name
    log "no department name"
    res.status(403).json message: 'no department name'
    return
  agent = res.locals.agent
  agent.createDepartment { parentId: req.body.parentId,name: req.body.name },(err,dp) ->
    if err
      log "failed to create department",err
      res.status(403).json message: err
    else
      res.json dp       

router.put '/:id', (req, res) ->
  agent = res.locals.agent
  agent.updateDepartment { id: req.params.id,parentId: req.body.parentId,name: req.body.name },(err) ->
    if err
      log "failed to update department",err
      res.status(403).json message: err
    else
      res.json message: 'OK'

router.delete '/:id', (req, res) ->
  agent = res.locals.agent
  agent.deleteDepartment { id: req.params.id },(err) ->
    if err
      log "failed to del department",err
      res.status(403).json message: err
    else
      res.json message: 'OK'

router.get '/:id/users', (req, res) ->
  agent = res.locals.agent
  agent.users { recursive: (req.query.recursive in [undefined,'yes','true']),departmentId: req.params.id },(err,list) ->
    if err
      log "failed to get department users",err
      res.status(403).json message: err
    else
      res.json list

router.delete '/:id/:userId', (req, res) ->
  agent = res.locals.agent
  agent.user { id: req.params.userId }, (err,user) ->
    if err
      log 'failed to get user',err
      res.status(403).json message: err
    else
      departments = (d for d in user.department when d != parseInt(req.params.id))
      if departments.length == 0
        return res.status(403).json message: "#{req.params.userId} must belong to at least one department."
      agent.updateUser { id: req.params.userId, departmentIds: departments }, (derr) ->
        if derr
          res.status(403).json message: derr
        else 
          res.json message: 'OK'

router.post '/:id/:userId', (req, res) ->
  agent = res.locals.agent
  agent.user { id: req.params.userId }, (err,user) ->
    if err
      log 'failed to get user',err
      res.status(403).json message: err
    else
      if parseInt(req.params.id) in user.department
        log "user #{req.params.userId} already in this department"
        return res.json message: 'OK'
      user.department.push  parseInt(req.params.id)
      agent.updateUser { id: req.params.userId, departmentIds: user.department }, (derr) ->
        if derr
          res.status(403).json message: derr
        else 
          res.json message: 'OK'                   

module.exports = router            