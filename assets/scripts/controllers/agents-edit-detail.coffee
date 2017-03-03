$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
toastr = require 'toastr'
_ = require '../models/main'
$ ->
  $('.del-row').off('click').on 'click', ->
    $(this).parent().parent().remove()
  eventsMap = [
    { code: 'subscribe', name: '订阅' }
    { code: 'unsubscribe', name: '退阅' }
    { code: 'scancode_push', name: '扫码推(不显示二维码内容)' }
    { code: 'scancode_waitmsg', name: '扫码(显示二维码内容)' }
    { code: 'enter_agent', name: '用户进入App' }
    { code: 'click', name: '点击菜单' }
    { code: 'location', name: '上报地理位置' }
    { code: 'view',name: '点击菜单跳转链接'}
    { code: 'pic_sysphoto',name: '弹出系统拍照发图' }
    { code: 'pic_photo_or_album',name: '弹出拍照或者相册发图'}
    { code: 'pic_weixin',name: '弹出微信相册发图器'}
    { code: 'location_select',name: '弹出地理位置选择器'}
    { code: 'batch_job_result',name: '异步任务完成'}
    { code: 'client_ip',name: '上报IP'}
  ]
  $('#add-msg').on 'click', ->
    lastId = parseInt($('#msg-table tr').last().attr('id').replace('line','')) + 1
    row = "<tr id='line#{lastId}'>
    <td><select class='change-type form-control'><option value='text'>文本</option><option value='callback'>回调模式</option></select></td>
    <td><input type='text' class='msg-content form-control'/></td>
    <td><input type='text' class='msg-condition form-control' value='.*'/></td>
    <td><button type='button' class='del-row btn btn-default'>删除</button></td>
    </tr>"
    $('#msg-table').append row
    $('.del-row').off('click').on 'click', ->
      $(this).parent().parent().remove()

  $('#add-evt').on 'click', ->
    eventSelection = "<select class='change-evt form-control'>" + ("<option value='#{evt.code}'>#{evt.name}</option>" for evt in eventsMap).join('') + "</select>"
    lastId = parseInt($('#evt-table tr').last().attr('id').replace('line','')) + 1
    row = "<tr id='line#{lastId}'>
    <td><select class='change-type form-control'><option value='text'>文本</option><option value='callback'>回调模式</option></select></td>
    <td><input type='text' class='evt-content form-control'/></td>
    <td>#{eventSelection}</td>
    <td><button type='button' class='del-row btn btn-default'>删除</button></td>
    </tr>"
    $('#evt-table').append row
    $('.del-row').off('click').on 'click', ->
      $(this).parent().parent().remove()        
    $('.change-type').off('change').on 'change', ->
      lineno = $(this).parent().parent().attr('id')
      $("##{lineno} .evt-content").val('')

  $('#save').on 'click', ->
    # messages
    messages = []
    $('#msg-table tr').each (i,row) ->
      return unless parseInt($(row).attr('id').replace('line','')) > 0
      msg = type: $(row).find('select').val()
      switch msg.type
        when 'text'
          msg.words = $(row).find('input.msg-content').val() or ''
          msg.match = $(row).find('input.msg-condition').val() or '.*'
        when 'callback'
          msg.url = $(row).find('input.msg-content').val() or ''
          msg.match = $(row).find('input.msg-condition').val() or '.*'
        else return
      messages.push msg
    # events
    events = {}
    $('#evt-table tr').each (i,row) ->
      return unless parseInt($(row).attr('id').replace('line','')) > 0
      evt = $(row).find('select.change-evt').val()
      console.log evt
      data = type: $(row).find('select.change-type').val()
      switch data.type
        when 'text'
          data.words = $(row).find('input.evt-content').val() or ''
        when 'callback'
          data.url = $(row).find('input.evt-content').val() or ''
        else return
      events[evt] = data
    console.log messages
    for msg in messages
      msg.match = '.*' unless msg.match?.length > 0
      switch msg.type
        when 'text'
          true
        when 'callback'
          unless msg.url?.length > 0
            toastr.error "#{msg.match}对应的回调地址不存在"
            return
          unless /https?:\/\/.+/.test msg.url
            toastr.error "#{msg.match}对应的回调地址不是合法url"
            return            
        else
          toastr.error "不支持的消息响应类型#{msg.type}"
          return
    for evt,cfg of events
      evtName = (e.name for e in eventsMap when e.code == evt)[0]
      switch cfg.type
        when 'text'
          true
        when 'callback'
          unless cfg.url?.length > 0
            toastr.error "#{evtName}事件对应的回调地址不存在"
            return
          unless /https?:\/\/.+/.test cfg.url
            toastr.error "#{evtName}事件对应的回调地址不是合法url"
            return           
        else
          toastr.error "不支持的事件响应类型#{cfg.type}"
          return
    console.log events
    url = $('input.submit_url').val()
    $.ajax
      type: 'POST'
      url: url
      data: JSON.stringify(messages: messages,events: events)
      contentType: "application/json; charset=utf-8"
      dataType: 'json'
      success: (data) ->
        window.location.href = '/agents'
