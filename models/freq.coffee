cache = require './cache'

Freq = 
  get: (msgId,cb) ->
    cache.get "waas:freq:#{msgId}", (err,reply) ->
      return cb(reply) if reply?.length > 0
      return cb(null)
  put: (msgId,content) ->
    cache.set "waas:freq:#{msgId}", content
    cache.expire "waas:freq:#{msgId}",60  # 1 minute

module.exports = Freq
