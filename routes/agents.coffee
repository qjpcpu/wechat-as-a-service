async = require 'async'
express = require 'express'
debug = require 'debug'
merge = require 'merge'
Agent = require '../models/agent'
authorization = require '../models/authorization'

router = express.Router()
log = debug 'http'

router.use authorization.browserAuth()

router.get '/',(req,res) ->
  Agent.find order: 'identifier DESC', (err,agents) ->
    log agents
    for ag in agents
      ag.messagesCount = ag.messages.length
      ag.eventsCount = if typeof ag.events == 'string' then 0 else (k for k,v of ag.events).length
    res.render 'agents/index', apps: agents
    
router.get '/new', (req,res) ->
  res.render 'agents/new'

router.get '/:id', (req,res) ->
  res.redirect "/agents/#{req.params.id}/edit"

router.delete '/:id',(req,res) ->
  Agent.findOne where: id: req.params.id, (err,client) ->
    if client
      client.destroy (err) -> if err then res.status(400).json message: 'fail' else res.json message: 'ok'
    else
      res.status(400).json message: '无此App'

router.get '/:id/edit', (req,res) ->
  Agent.findOne where: id: req.params.id, (err,agent) ->
    if agent
      log agent
      res.render 'agents/new',agent
    else
      res.render 'agents/index'


router.get '/:id/edit-detail', (req,res) ->
  Agent.findOne where: id: req.params.id, (err,agent) ->
    if agent
      log agent
      res.render 'agents/edit-detail',agent
    else
      res.render 'agents/index'

router.post '/:id/detail', (req,res) ->
  Agent.findOne where: id: req.params.id, (err,agent) ->
    if agent
      log req.body
      agent.messages = req.body.messages if req.body.messages
      agent.events = req.body.events if req.body.events
      agent.save (dberr,ag) ->
        if ag
          data = {}
          for k,v of ag
            data[k] = v if k in ['id','identifier','messages','events','name']
          res.json data
        else
          res.status(400).json message: 'fail to update app'
    else
      res.status(404).json message: 'no such app'

router.post '/:id', (req,res) ->
  async.waterfall [
    (cb) ->
      Agent.findOne where: id: req.params.id, (err,agent) -> if agent then cb(null,agent) else cb('无此App')
    (agent,cb) ->
      if req.body.name
        Agent.findOne where: { name: req.body.name,id: {ne: agent.id} }, (err,ag) ->
          agent.name = req.body.name
          if ag then cb("已存在同名App") else cb(null,agent)  
      else      
        cb(null,agent)
    (agent,cb) ->
      if req.body.token
        Agent.findOne where: { token: req.body.token,id: {ne: agent.id} }, (err,ag) ->
          if ag
            cb("该token属于#{ag.name}")
          else
            agent.token = req.body.token
            cb(null,agent)
      else
        cb(null,agent)
    (agent,cb) ->
      if req.body.id
        Agent.findOne where: { identifier: req.body.id,id: {ne: agent.id} }, (err,ag) ->
          if ag
            cb("该id已存在,属于#{ag.name}")
          else
            agent.identifier = req.body.id
            cb(null,agent)
      else
        cb(null,agent)
  ], (err,agent) ->
    if err
      res.status(400).json message: err
    else
      agent.encodingAesKey = req.body.encodingAesKey if req.body.encodingAesKey
      agent.save (dberr) ->
        if dberr
          log dberr
          res.status(400).json message: '无法新建App'
        else
          res.json agent

router.post '/', (req,res) ->
  async.waterfall [
    (cb) ->
      if req.body.name
        Agent.findOne where: name: req.body.name, (err,agent) ->
          if agent then cb("已存在同名App") else cb(null,{name: req.body.name})
      else
        cb('无App名称')
    (info,cb) ->
      if req.body.token
        info.token = req.body.token
        cb null,info
      else
        cb('无App token')
    (info,cb) ->
      if req.body.id
        Agent.findOne where: identifier: req.body.id, (err,agent) ->
          if agent
            cb("该id已存在,属于#{agent.name}")
          else
            info.identifier = req.body.id
            cb(null,info)
      else
        cb('无App id')        
    (info,cb) ->
      if req.body.encodingAesKey
        info.encodingAesKey = req.body.encodingAesKey
        cb(null,info)
      else
        cb('无App encodingAesKey')
  ], (err,info) ->
    if err
      log err
      res.status(400).json message: err
    else
      agent = new Agent info
      agent.save (dberr,agent) ->
        if dberr
          log dberr
          res.status(400).json message: '无法新建App'
        else
          res.json agent


module.exports = router            