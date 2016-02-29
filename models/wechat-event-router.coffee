debug = require 'debug'
Cc = require 'change-case'
rest = require 'restler'
moment = require 'moment'
async = require 'async'
Agent = require './agent'

log = debug 'waas:wechat-router'
class WeChatEventRouter
  handle: (entity,cb) ->
    Agent.findOne where: identifier: entity.agentId.toString(), (camErr,agent) ->
      if camErr or (not agent?)
        log 'no wechat app found',camErr
        return cb(null,'')    
      evt = Cc.lowerCase entity.event
      events = agent.events
      unless events[evt]
        log 'Swallow event', entity
        return cb(null,'')
      return cb("no such event handler: #{events[evt].type}") unless events[evt].type in ['text','callback']
      return cb(null,events[evt].words or '') if events[evt].type == 'text'
      return cb('no callback url') unless events[evt].url
  
      url = events[evt].url
  
      if agent.callbackToken?.length > 0
        sig = Agent.calSignature agent.callbackToken
        url = "#{url}?timestamp=#{sig.timestamp}&nonce=#{sig.nonce}&signature=#{sig.signature}"
  
      log "forword message to #{url}",entity
      rest.postJson(url,
        entity
        { timeout: 4000 }
      ).on('timeout', (ms) ->
        log 'request timeout, maybe you request a wrong url',url
        cb 'request timeout'
      ).on 'complete', (result) ->
        if result instanceof Error
          log 'err ocurrs',result
          cb result
        else
          log "get response",result
          cb null,result

module.exports = WeChatEventRouter