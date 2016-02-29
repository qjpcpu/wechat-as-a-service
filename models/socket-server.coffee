debug = require 'debug'
async = require 'async'
Client = require './client'
jwt = require 'jsonwebtoken'
jwtCfg = require('../config').jwt
QRCode = require 'qrcode'
urlParse = require 'url-parse'

loginJwt = jwtCfg.login
sessionJwt = jwtCfg.session
ticketJwt = jwtCfg.ticket
log = debug 'waas:socket-server'

# auth flow
# 1. client触发client_connect事件,上报数据为:
# clientId: xxx
# redirectUri: http://yyy/path # 该回调地址必须和登记域名一致或为localhost/127.0.0.1
# info: extra_info # 附加数据字符串
# 2. 服务端触发client的qrcode_transfer,传递数据{ imageDataUrl: 'baeefw' },client使用该url绘制二维码
# 3. 用户扫描二维码后,服务端触发client的qrcode_scan事件,传递数据:
# state: success/fail
# ticket: ticket
# redirectUri: http://yyy/path

SocketServer = 
  io: null
  get: -> @io
  set: (sio) -> 
    @io = sio
    @io.on 'connection', (socket) ->
      socket.on 'client_connect', (data) ->
        log 'got data',data
        async.waterfall [
          (cb) -> if data.clientId then cb(null,data.clientId) else cb('No client id found')
          (clientId,cb) -> if data.origin then cb(null,data.clientId) else cb('No origin found')
          (clientId,cb) ->
            Client.findOne where: identifier: clientId, (gerr,client) ->
              unless client
                log "can not find client",gerr
                socket.emit 'qrcode_aquire', message: "非法的clientId:#{data.clientId}"
                cb "非法的clientId:#{data.clientId}"
              else
                cb(null,client)
          (client,cb) ->
            if data.origin in ['127.0.0.1','localhost',urlParse(client.redirectUri,true).hostname]
              log "check client origin[#{data.origin}] OK"
              cb(null,client)
            else
              log "client origin: #{data.origin}非法"
              cb "client origin: #{data.origin}非法"
          (client,cb) ->
            if data.session
              jwt.verify data.session, jwtCfg.session.secret, (jwterr, sessionToken) ->
                if sessionToken? and sessionToken?.type == 'session'
                  cb null,client,sessionToken
                else
                  cb null,client
            else
              cb null,client
        ], (err,client,sessionPayload) ->
          if err
            log "Lander Error:",err
            return
          if sessionPayload
            redirectUri = data.redirectUri or client.redirectUri
            url = urlParse(redirectUri,true)
            url.query.info = data.info if data.info
            unless url.hostname in ['127.0.0.1','localhost',urlParse(client.redirectUri,true).hostname]
              url.hostname = urlParse(client.redirectUri,true).hostname
            sessionPayload.type = 'tickt'
            ticket = jwt.sign sessionPayload, client.secret,ticketJwt.options
            url.query.ticket = ticket
            socket.emit 'qrcode_scan',
              state: 'success'
              ticket: ticket
              redirectUri: url.toString()
              session: data.session
            log sessionPayload,'already signed in, redirecting...'
          else
            payload =
              type: 'login'
              clientId: client.identifier
            payload.redirectUri = data.redirectUri if data.redirectUri
            payload.info = data.info if data.info
            log "send qrcode payload",payload
            
            loginCode = jwt.sign payload, loginJwt.secret,loginJwt.options  # expires in 5min
            QRCode.toDataURL loginCode, (err,url) ->
              socket.join loginCode
              socket.emit 'qrcode_transfer',loginCode: url

module.exports = SocketServer
