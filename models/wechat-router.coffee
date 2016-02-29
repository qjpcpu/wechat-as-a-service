WeChatEventRouter = require './wechat-event-router'
WeChatSytemEventRouter = require './wechat-system-event-router'
WeChatMsgRouter = require './wechat-msg-router'
Cc = require 'change-case'
async = require 'async'
jwt = require 'jsonwebtoken'
jwtCfg = require('../config').jwt

class WeChatRouter
  handle: (entity,cb) ->
    switch entity.msgType
      when 'text' then  (new WeChatMsgRouter()).handle entity,cb
      when 'event'
        evt = Cc.lowerCase entity.event
        async.waterfall [
          (acb) ->
            if /^scancode/.test(evt) and entity.scanCodeInfo.ScanType == 'qrcode'
              key = entity.scanCodeInfo.ScanResult
              jwt.verify key, jwtCfg.login.secret, (jwterr, loginCode) ->
                if loginCode?.type == 'login' or jwterr?.name == 'TokenExpiredError'
                  acb(null,'system_event_router')
                else
                  acb(null,'event_router')
            else
              acb(null,'event_router')
        ], (err,routerName) ->
          routerName = routerName or 'event_router'
          switch routerName
            when 'system_event_router' then (new WeChatSytemEventRouter()).handle entity,cb
            when 'event_router' then (new WeChatEventRouter()).handle entity,cb
            else (new WeChatEventRouter()).handle entity,cb
      else cb("no router for #{entity.msgType}")

module.exports = WeChatRouter