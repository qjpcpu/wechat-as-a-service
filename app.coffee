express = require('express')
path = require('path')
favicon = require('serve-favicon')
logger = require('morgan')
cookieParser = require('cookie-parser')
cookieSession = require 'cookie-session'
bodyParser = require('body-parser')
routes = require('./routes/index')
wechat = require './routes/wechat'
departments = require './routes/departments'
users = require './routes/users'
roles = require './routes/roles'
agents = require './routes/agents'
clients = require './routes/clients'
tokens = require './routes/tokens'

app = express()

# view engine setup
app.set 'views', path.join(__dirname, 'views')
app.set 'view engine', 'jade'

app.use favicon(path.join(__dirname, 'public', 'favicon.ico'))
app.use logger('dev')
app.use bodyParser.json()
app.use cookieSession {
  secret: 'sOZ9bakJhS8CnNCotHlnI4Jpv5dqFmHlcjOBJ'
  cookie: { secure: true, maxAge: 60 * 60 * 48 }
}
app.use bodyParser.urlencoded(extended: false)
app.use cookieParser()
app.use express.static(path.join(__dirname, 'public'))
app.use '/', routes
app.use '/wechat', wechat
app.use '/departments', departments
app.use '/users',users
app.use '/roles',roles
app.use '/agents',agents
app.use '/clients',clients
app.use '/tokens',tokens

# catch 404 and forward to error handler
app.use (req, res, next) ->
  err = new Error('Not Found')
  err.status = 404
  next err
  return
# error handlers
# development error handler
# will print stacktrace
if app.get('env') == 'development'
  app.use (err, req, res, next) ->
    res.status err.status or 500
    res.render 'error',
      message: err.message
      error: err
    return
# production error handler
# no stacktraces leaked to user
app.use (err, req, res, next) ->
  res.status err.status or 500
  res.render 'error',
    message: err.message
    error: {}
  return
module.exports = app