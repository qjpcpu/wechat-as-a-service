caminte = require 'caminte'
config = require '../config'
Schema = caminte.Schema
config = 
  driver: "redis"
  host: config.redis.host
  port: config.redis.port
  password: config.redis.password or ''
  database: config.redis.db

schema = new Schema config.driver, config

module.exports = schema