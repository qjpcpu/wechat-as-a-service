$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
toastr = require 'toastr'
_ = require '../models/main'
$ ->
  $('#create-app').on 'click', ->
    toastr.clear()
    name = $('#name').val()
    unless name?.length > 0
      toastr.error 'App名称为空'
      return
    id = parseInt $('#identifier').val()
    unless 0 < id < 100
      toastr.error 'App Id必须为正整数'
      return
    token = $('#token').val()
    unless token?.length > 0
      toastr.error 'token为空'
      return
    encodingAesKey = $('#aesKey').val()
    unless encodingAesKey?.length
      toastr.error 'AES密钥为空'
      return
    url = $('input.submit_url').val()
    $.post(url,
      name: name
      token: token
      encodingAesKey: encodingAesKey
      id: id
    , ((res) ->
      redirectUrl = if /agents\/?$/.test url then "/agents/#{res.id}/edit-detail" else '/agents'
      window.location.href = redirectUrl
    ),'json').fail (err) ->
      toastr.error err.responseJSON?.message
