$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
toastr = require 'toastr'
moment = require 'moment'
_ = require '../models/main'
$ ->
  $('#query').on 'click', ->
    $.ajax
      url: '/tokens/verify'
      type: 'POST'
      data: accessToken: $('#token').val()
      success: (data) ->
        htmlText = "<tr><td>App名称: #{data.agent.name}</td></tr>"
        htmlText += "<tr><td>client: #{data.client.name}</td></tr>"
        htmlText += "<tr><td>失效时间: #{moment.unix(data.exp).format('YYYY-MM-DD HH:mm:ss')}</td></tr>"
        $('#result').html htmlText
      error: (data) ->
        data = JSON.parse data.responseText
        htmlText = "<tr><td>错误: #{data.message}</td></tr>"
        $('#result').html htmlText
