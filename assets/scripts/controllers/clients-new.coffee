$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
toastr = require 'toastr'
_ = require '../models/main'
$ ->
  $('#create-client').on 'click', ->
    toastr.clear()
    name = $('#name').val()
    unless name?.length > 0
      toastr.error '客户系统名称为空'
      return
    redirectUri = $('#redirectUri').val()
    unless redirectUri?.length > 0
      toastr.error '回调地址为空'
      return
    unless /https?:\/\/.+/.test redirectUri
      toastr.error '回调地址url非法'
      return
    url = $('input.submit_url').val()
    $.post(url,
      name: name
      redirectUri: redirectUri
      agentIdentifier: $('#agentIdentifier').val()
    , ((res) ->
      redirectUrl = if /clients\/?$/.test url then "/clients/#{res.id}/" else '/clients'
      window.location.href = redirectUrl
    ),'json').fail (err) ->
      toastr.error err.responseJSON?.message
