$ = require 'jquery-browserify'
Wechat = require './lander'
$ ->
  lander = new Wechat
    clientId: $('#clientId').val()

  lander.login "login-qrcode"

module.exports = 'index'