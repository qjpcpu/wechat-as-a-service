debug = require 'debug'
async = require 'async'
config = require '../config'

log = debug 'waas:authorization'

Authorization = 
  browserAuth: ->
    fun = (req,res,next) ->
      unless config.administrators? and config.administrators instanceof Array and config.administrators.length > 0
        log "尚未配置管理员"
        next()
        return
      if req.session.currentUser?
        next()
      else
        res.redirect '/'
    fun

module.exports = Authorization
