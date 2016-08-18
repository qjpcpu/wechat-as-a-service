redis = require 'redis'
config = require '../config'
cache = redis.createClient
  host: config.redis.host
  port: config.redis.port
  password: config.redis.password or ''
  database: config.redis.db

cache.on 'error', (err) ->
  console.log "cache datastore error"
  
module.exports = cache