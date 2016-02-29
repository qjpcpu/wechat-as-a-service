clone = require 'clone'
xml2js = require 'xml2js'
xmlparser = require 'express-xml-bodyparser'
express = require 'express'
debug = require 'debug'
async = require 'async'
Cc = require 'change-case'
Agent = require '../models/agent'
WeChatRouter = require '../models/wechat-router'
moment = require 'moment'

router = express.Router()
log = debug('http')

router.use '/callback',xmlparser({trim: false,normalize: false,normalizeTags: false, explicitArray: false}), (req,res,next) ->
  if (not req.query.echostr?) and (not req.body.xml?.Encrypt?)
    res.status(403).json(message: 'invalid request, lost body')
    return
  if (not req.query.timestamp?) or (not req.query.nonce?) or (not req.query.msg_signature?)
    res.status(403).json message: 'invalid request from unkown source'
    return
  async.waterfall [
    ((cb) ->
      if req.body.xml?.AgentID
        Agent.findOne where: identifier: req.body.xml.AgentID, (camErr,agent) ->
          if camErr then cb(null,null) else cb(null,agent)
      else
        cb(null,null)
    )
    ((agent,cb) ->
      if agent
        cb(null,agent)
      else
        Agent.all (err,agents) ->
          for agent in agents
            vr = agent.validateUrl
              timestamp: req.query.timestamp
              nonce: req.query.nonce
              signature: req.query.msg_signature
              message: req.query.echostr or req.body.xml.Encrypt
            if vr
              return cb(null,agent)
          cb('No agent found')
    )
  ], (err,agent) ->
    if err
      if req.query.echostr
        res.send req.query.echostr
      else
        res.status(404).json message: err
      return
    validReq = agent.validateUrl
      timestamp: req.query.timestamp
      nonce: req.query.nonce
      signature: req.query.msg_signature
      message: req.query.echostr or req.body.xml.Encrypt
    unless validReq
      res.status(403).json(message: 'invalid callback request from unkown source')
    else
      if req.query.echostr
        req.query.echostr = agent.decrypt req.query.echostr
        next()
      else
        decryptMsg = agent.decrypt req.body.xml.Encrypt
        xml2js.parseString decryptMsg,{explicitArray : false}, (err,msg) ->
          if err
            log decryptMsg,err
            res.json message: 'ok'
          else
            req.body.xml = msg.xml
            next()

router.get '/callback', (req,res) -> 
  res.send req.query.echostr

router.post '/callback',(req,res) ->  
  xmlData = clone(req.body.xml)
  log xmlData
  jsData = {}
  for k,v of xmlData when k not in ['FromUserName','ToUserName','CreateTime']
    jsData[Cc.camelCase(k)] = v
  jsData.fromUser = xmlData.FromUserName
  (new WeChatRouter()).handle jsData,(err,data) ->
    if err
      log "error happens when handle #{req.body.xml}\nerr was: #{err}"
      response = 
        toUser: xmlData.FromUserName
        fromUser: xmlData.ToUserName
        time: "#{moment().unix()}"
        msgType: 'text'
        content: "oops! error happens"
      Agent.findOne where: identifier: jsData.agentId, (camErr,agent) ->
        agent.render response.msgType,response,(err,xmlStr) ->
          res.render "wechat/wrap", agent.encrypt(xmlStr)        
    else
      response = {}
      if typeof data == 'object' and data?.msgType in ['text','news','image','music','video','voice']
        response[Cc.camelCase(k)] = v for k,v of data             
      else if typeof data == 'string'
        response.msgType = 'text'
        response.content = data
      else
        log "bad response from server",data
        response = 
          msgType: 'text'
          content: "oops! bad response from server"          

      response.toUser = xmlData.FromUserName
      response.fromUser = xmlData.ToUserName
      response.time = "#{moment().unix()}"
      Agent.findOne where: identifier: jsData.agentId, (camErr,agent) ->
        agent.render response.msgType,response,(err,xmlStr) ->
          res.render "wechat/wrap", agent.encrypt(xmlStr)

module.exports = router
