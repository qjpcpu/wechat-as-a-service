socketio = require 'socket.io-client'
CrossStorage = require 'cross-storage'

address = '{{host}}'
address = "#{window.location.protocol}//#{window.location.host}" unless /https?:\/\/.+/.test(address)

sessionName = '_waas_'
storage = new CrossStorage.CrossStorageClient("#{address}/local_talk")

# lander = new WechatLander clientId: 'aa'
# lander.on 'error', (data,cb) ->
#   console.log data
#   cb(bubble: false)
# lander.on 'qrcode', (data,cb) ->
#   console.log 'get qrcode',data.qrimage
#   cb(bubble: true)
# lander.on 'scan', (data,cb) ->
#   cb(bubble: true)
# lander.login 'qrcode-div-id'

class WechatLander
  constructor: (params) ->
    console.error "Can't find clientId when initialization" unless params.clientId
    console.log "I would connect to #{address}"
    @clientId = params.clientId
    @redirectUri = params.redirectTo
    @info = params.info  # extra info
  
  # error/qrcode/scan
  on: (evt,callback) ->
    lander = this
    lander.hooks = {} unless lander.hooks
    if callback and typeof callback == 'function'
      lander.hooks[evt] = callback

  logout: (callback) ->
    storage.onConnect().then( ->
      storage.del sessionName
    ).then(->
      callback() if callback and typeof callback == 'function'
    ).catch (err) ->
      console.log err
      callback() if callback and typeof callback == 'function'

  login: (targetId) ->
    lander = this
    lander.socket = socketio address, forceNew: true
    wbConnect = (sessionToken) ->
      lander.socket.emit 'client_connect',
        clientId: lander.clientId
        info: lander.info
        redirectUri: lander.redirectUri
        origin: window.location.hostname
        session: sessionToken
    storage.onConnect().then( ->
      storage.get(sessionName)
    ).then((st)->
      if st? then wbConnect(st) else wbConnect()
    ).catch (err) ->
      console.log err
      wbConnect()

    lander.socket.on 'qrcode_aquire', (data) ->
      fun = (opts) ->
        return if opts?.bubble == false
        container = document.getElementById targetId
        unless container
          console.error "Can't find container ##{targetId}, maybe your DOM is not ready"
          return
        p = document.createElement 'p'
        txt = document.createTextNode data.message
        p.appendChild txt
        container.appendChild p
      if lander.hooks?.error
        lander.hooks.error(data,fun)
      else
        fun bubble: true

    lander.socket.on 'qrcode_transfer', (data) ->
      console.log "Received qrcode, prepare to show..."
      fun = (opts) ->
        return if opts?.bubble == false
        unless targetId
          console.error 'No qrcode container DIV found'
          return
        container = document.getElementById targetId
        unless container
          console.error "Can't find container ##{targetId}, maybe your DOM is not ready"
          return
        img = document.createElement "img"
        img.setAttribute 'src',data.loginCode
        while container.firstChild
          container.removeChild container.firstChild
        container.appendChild img
      if lander.hooks?.qrcode 
        lander.hooks.qrcode qrimage: data.loginCode,fun
      else
        fun bubble: true


    lander.socket.on 'qrcode_scan', (data) ->
      goFunc = (opts) ->
        if data.state == 'success'
          return if opts?.bubble == false
          window.location.href = data.redirectUri
        else
          console.log data
      console.log "User scanned qrcode! Going to redirect..."
      lander.socket.disconnect()
      finalization = ->
        if lander.hooks?.scan
          lander.hooks.scan state: data.state,ticket: data.ticket,goFunc
        else
          goFunc(bubble: true)
      storage.onConnect().then( ->
        if data?.state == 'success' and data?.session
          storage.set sessionName, data.session
        else
          storage.del sessionName
      ).then(->
        finalization()
      ).catch (err) ->
        console.log err
        finalization()       


module.exports = WechatLander