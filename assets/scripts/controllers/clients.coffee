$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
toastr = require 'toastr'
_ = require '../models/main'
$ ->
  delObj = null
  $('.del-row').on 'click', ->
    delObj = $(this)
    $('#modal-del').modal 'show'
  $('#confirm-del').on 'click', ->
    toastr.clear()
    return unless delObj
    row = delObj.parent().parent()
    id = row.attr('id')
    $.ajax(
      url: "/clients/#{id}"
      type: 'DELETE'
    ).success (data) ->
      row.remove()
      toastr.success 'OK'
    delObj = null
    
  $('.get-token').on 'click', ->
    id = $(this).parent().parent().attr('id')
    $.ajax
      url: "/clients/#{id}/access_token"
      type: 'POST'
      success: (data) ->
        $('#token-body').text data.accessToken
        $('#modal-token').modal 'show'
      error: (data) ->
        data = JSON.parse data.responseText
        toastr.error data.message

