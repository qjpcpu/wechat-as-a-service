$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
toastr = require 'toastr'
_ = require '../models/main'
$ ->
  delObj = null
  $('.del-row').on 'click', ->
    delObj = $(this)
    $('.modal').modal 'show'
  $('#confirm-del').on 'click', ->
    toastr.clear()
    return unless delObj
    row = delObj.parent().parent()
    id = row.attr('id')
    $.ajax(
      url: "/agents/#{id}"
      type: 'DELETE'
    ).success (data) ->
      row.remove()
      toastr.success 'OK'
    delObj = null
