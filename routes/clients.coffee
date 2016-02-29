async = require 'async'
express = require 'express'
debug = require 'debug'
merge = require 'merge'
Client = require '../models/client'
Agent = require '../models/agent'
authorization = require '../models/authorization'

router = express.Router()
log = debug 'http'

router.use authorization.browserAuth()

router.get '/',(req,res) ->
  Agent.find order: 'identifier DESC', (aerr,agents) ->
    table = {}
    table[ag.identifier] = ag.name for ag in agents
    Client.find order: 'identifier DESC', (err,clients) ->
      c.appName = table[c.agentIdentifier] for c in clients
      log clients
      res.render 'clients/index', clients: clients

router.delete '/:id',(req,res) ->
  Client.findOne where: id: req.params.id, (err,client) ->
    if client
      client.destroy (err) -> if err then res.status(400).json message: 'fail' else res.json message: 'ok'
    else
      res.status(400).json message: '无此client'

router.post '/:id/access_token',(req,res) ->
  Client.findOne where: id: req.params.id, (err,client) ->
    if client
      res.json accessToken: client.generateAccessToken()
    else
      res.status(400).json message: '无此client'

router.get '/new', (req,res) ->
  Agent.find order: 'identifier DESC', (err,agents) ->
    res.render 'clients/new',apps: agents or []

router.get '/:id', (req,res) ->
  res.redirect "/clients/#{req.params.id}/edit"

router.get '/:id/edit', (req,res) ->
  Agent.find order: 'identifier DESC', (err,agents) ->
    Client.findOne where: id: req.params.id, (err,client) ->
      if client
        log client
        client.apps = agents or []
        res.render 'clients/new',client
      else
        res.render 'clients/index'

router.post '/:id', (req,res) ->
  async.waterfall [
    (cb) ->
      Client.findOne where: id: req.params.id, (err,client) -> if client then cb(null,client) else cb('无此client')
    (client,cb) ->
      if req.body.name
        Client.findOne where: { name: req.body.name,id: {ne: client.id} }, (err,ag) ->
          client.name = req.body.name
          if ag and ag.id != client.id then cb("已存在同名client") else cb(null,client)  
      else      
        cb(null,client)
    (client,cb) ->
      if req.body.redirectUri
        if /https?:\/\/.+/.test req.body.redirectUri
          client.redirectUri = req.body.redirectUri
          cb(null,client)
        else
          cb('回调地址非法')
      else      
        cb(null,client)        
  ], (err,client) ->
    if err
      log err
      res.status(400).json message: err
    else
      client.agentIdentifier = req.body.agentIdentifier if req.body.agentIdentifier
      client.save (dberr) ->
        if dberr
          log dberr
          res.status(400).json message: '无法新建client'
        else
          res.json client

router.post '/', (req,res) ->
  async.waterfall [
    (cb) ->
      if req.body.name
        Client.findOne where: name: req.body.name, (err,client) ->
          if client then cb("已存在同名客户") else cb(null,{name: req.body.name})
      else
        cb('无客户系统名称')
    (info,cb) ->
      if req.body.redirectUri? and /https?:\/\/.+/.test req.body.redirectUri
        info.redirectUri = req.body.redirectUri
        cb(null,info)
      else
        cb('非法回调地址')
  ], (err,info) ->
    if err
      res.status(400).json message: err
    else
      info.agentIdentifier = req.body.agentIdentifier if req.body.agentIdentifier
      client = new Client info
      client.save (dberr,client) ->
        if dberr
          log dberr
          res.status(400).json message: '无法新建客户系统配置'
        else
          res.json client


module.exports = router            
