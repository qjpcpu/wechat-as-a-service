database = require './database'
async = require 'async'
moment = require 'moment'
debug = require 'debug'
sha1 = require 'sha1'
restler = require 'restler'
WXBizMsgCrypt = require 'wechat-crypto'
path = require 'path'
jade = require 'jade'
rest = require 'restler'
config = require '../config'
uuid = require 'node-uuid'
cache = require './cache'
redis = require 'redis'

log = debug 'waas:agent'

Agent = database.define 'Agent',
  {
  	# agent display name
    name: { type: database.String,index: true }
    # agent id
    identifier: { type: database.String,index: true }
    # agent token
    token: database.String
    # AES key
    encodingAesKey: type: database.String
    # wechat id
    corpId: type: database.String
    # wechat secret
    corpSecret: type: database.String
    # waas client use this token to validate request from waas, optional
    callbackToken: type: database.String
    # event callback configurations
    events: { type: database.JSON, default: {} }
    # messages router configurations
    messages: { type: database.JSON,default: [] }

    accessToken: type: database.String
    accessTokenExpiredAt: type: database.String
  }

# middlewares
Agent.beforeSave = (next) ->
  this.corpId = config.wechat.corpId unless this.corpId?.length > 0
  this.corpSecret = config.wechat.corpSecret unless this.corpSecret?.length > 0
  this.callbackToken = (new Buffer(uuid.v1())).toString('base64')[0..9] unless this.callbackToken?.length > 0
  next()
  
# class methods
Agent.calSignature = (seed) ->
  timestamp = "#{moment().unix()}"
  nonce = "#{Math.random()}"
  signature = sha1 [seed,timestamp,nonce].sort().join('')
  { timestamp: timestamp, nonce: nonce, signature: signature }

# instance methods
# 
# validate query parameters: nonce & timestamp & signature
Agent.prototype.validateUrl = (params) ->
  signature = sha1 [this.token,params.timestamp,params.nonce,params.message].sort().join('')
  return true if signature == params.signature
  log 'validate WeChat source failed, source query parameters is:', params
  false

# encrypt message(message should be string)
Agent.prototype.encrypt = (message) ->
  message = message?.toString() or ''
  cryptor = new WXBizMsgCrypt(this.token, this.encodingAesKey, this.corpId)
  message = cryptor.encrypt(message)
  timestamp = "#{moment().unix()}"
  nonce = (Math.random() * 10000000).toFixed(0)
  signature = cryptor.getSignature timestamp,nonce,message
  { message: message, timestamp: timestamp, nonce: nonce, signature: signature}  


Agent.prototype.decrypt = (message) ->
  cryptor = new WXBizMsgCrypt(this.token, this.encodingAesKey, this.corpId)
  cryptor.decrypt(message).message

# fetch access token
Agent.prototype.fetchAccessToken = (cb) ->
  agent = this
  if agent.accessToken? and agent.accessTokenExpiredAt? and moment() < moment(agent.accessTokenExpiredAt)
    cb null,agent.accessToken
  else
    rest.get('https://qyapi.weixin.qq.com/cgi-bin/gettoken',
      query:
        corpid: agent.corpId
        corpsecret: agent.corpSecret
    ).on "complete", (result) ->
      if result.errcode != 0
        log 'fetch wechat access token failed',result
        cb(result.errmsg)
      else
        # make sure token is available
        result.expires_in -= 60
        expiredAt = moment().add(result.expires_in, 'seconds')
        log "fetch access token success, it would expire at #{expiredAt.format('HH:mm')}"
        agent.accessToken = result.access_token
        agent.accessTokenExpiredAt = expiredAt.toJSON()
        agent.save -> cb(null,agent.accessToken)

# opts:
# id(optional)
Agent.prototype.departments = (opts,cb) ->
  rest.get('https://qyapi.weixin.qq.com/cgi-bin/department/list',
    query: 
      access_token: this.accessToken
      id: opts.id
  ).once 'complete', (result) ->
    if result.errcode != 0
      cb(result.errmsg)
    else
      cb(null,result.department)

Agent.prototype.createDepartment = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/department/create?access_token=#{this.accessToken}",
    name: opts.name
    parentid: opts.parentId or 1
  ).once 'complete', (res) ->
    if res.errcode != 0
      cb(res.errmsg)
    else
      cb(null,{id: res.id,name: opts.name})

Agent.prototype.updateDepartment = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/department/update?access_token=#{this.accessToken}",
    id: opts.id
    name: opts.name
    parentid: opts.parentId
  ).once 'complete', (err) ->
    if err.errcode == 0 then cb() else cb(err.errmsg)

Agent.prototype.deleteDepartment = (opts,cb) ->
  rest.get('https://qyapi.weixin.qq.com/cgi-bin/department/delete',
    query:
      access_token: this.accessToken
      id: opts.id
  ).once 'complete', (err) ->
    if err.errcode == 0 then cb() else cb(err.errmsg)

Agent.prototype.formatUser = (info) ->
  info.id = info.userid
  switch info.status
    when 0 then info.status = 'all'
    when 1 then info.status = 'watched'
    when 2 then info.status = 'disabled'
    when 4 then info.status = 'unwatched'
  switch info.gender?.toString()
    when '1' then info.sex = 'male'
    when '2' then info.sex = 'female'
  delete info.errmsg
  delete info.errcode
  delete info.userid
  delete info.gender
  info

Agent.prototype.users = (opts,cb) ->
  agent = this
  switch opts.status
    when 'all' then tag = 0
    when 'watched' then tag = 1
    when 'disabled' then tag = 2
    when 'unwatched' then tag = 4
    else tag = 1
  if opts.detail
    url = 'https://qyapi.weixin.qq.com/cgi-bin/user/list'
  else
    url = 'https://qyapi.weixin.qq.com/cgi-bin/user/simplelist'
  rest.get(url,
    query:
      access_token: this.accessToken
      department_id: opts.departmentId or 1
      fetch_child: (if opts.recursive then 1 else 0)
      status: tag
  ).once 'complete', (res) ->
    if res.errcode == 0
      list = (agent.formatUser(u) for u in res.userlist)
      cb(null,list)
    else
      cb res.errmsg

# get certain user
Agent.prototype.user = (opts,callback) ->
  agent = this
  rest.get('https://qyapi.weixin.qq.com/cgi-bin/user/get',
    query:
      access_token: this.accessToken
      userid: opts.id
  ).on 'complete', (result) ->
    if result.errcode != 0
      log "failed to get user[#{opts.id}]",result.errmsg
      callback result.errmsg
    else
      log "get user successful",result
      callback null,agent.formatUser(result)

Agent.prototype.createUser = (opts,cb) ->
  switch opts.sex
    when 'male' then opts.sex = 1
    when 'female' then opts.sex = 2

  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/user/create?access_token=#{this.accessToken}",
    userid: opts.id
    name: opts.name or opts.id
    department: (if opts.departmentIds?.length > 0 then opts.departmentIds else [1])
    position: opts.position
    mobile: opts.mobile
    email: opts.email
    gender: opts.sex
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

Agent.prototype.updateUser = (opts,cb) ->
  if opts.sex
    switch opts.sex
      when 'male' then opts.sex = 1
      when 'female' then opts.sex = 2
      else delete opts.sex
  if opts.state
    switch opts.state
      when 'enable' then opts.state = 1
      when 'disable' then opts.state = 0
      else delete opts.state
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/user/update?access_token=#{this.accessToken}",
    userid: opts.id
    name: opts.name
    department: opts.departmentIds
    position: opts.position
    mobile: opts.mobile
    email: opts.email
    gender: opts.sex
    enable: opts.state
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

# delete user: opts.id is userid
# delete users: opts.id is user list (Array)
Agent.prototype.deleteUser = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/user/batchdelete?access_token=#{this.accessToken}",
    useridlist: if typeof opts.id == 'string' then [opts.id] else opts.id
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

Agent.prototype.inviteUser = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/invite/send?access_token=#{this.accessToken}",
    userid: opts.id        
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb(null,res.type) else cb(res.errmsg)

Agent.prototype.formatMessage = (msg) ->
  # if you want send to all users, msg.users should be '@all'
  opts = 
    touser: if typeof msg.users == 'object' then msg.users.join('|') else msg.users
    toparty: if typeof msg.departmentIds == 'object' then msg.departmentIds.join('|') else msg.departmentIds
    totag: if typeof msg.tagIds == 'object' then msg.tagIds.join('|') else msg.tagIds
    msgtype: msg.type or 'text'
    agentid: parseInt(this.identifier)
    safe: if msg.encrypt then 1 else 0
  for k,v of opts when k in ['touser','toparty','totag']
    delete opts[k] unless v?
  if  (not opts.touser?) and (not opts.toparty?) and (not opts.totag?)
    throw 'No reciever found'
  ctrlUnicode = /[\u0000-\u0009\u000B-\u001F\u007F-\u009F]/g
  switch opts.msgtype
    when 'text'
      throw 'text message body must be string' unless typeof msg.body == 'string'
      msg.body = msg.body.replace ctrlUnicode,''
      opts[opts.msgtype] = { content: msg.body }
    when 'image','voice','file'
      throw 'message body must be hash object' unless typeof msg.body == 'object'
      throw 'no mediaId found in messge body' unless msg.body.mediaId
      opts[opts.msgtype] = { media_id: msg.body.mediaId }
    when 'video'
      throw 'message body must be hash object' unless typeof msg.body == 'object'
      throw 'no mediaId found in messge body' unless msg.body.mediaId
      throw 'no title found in video message body' unless msg.body.title
      opts[opts.msgtype] = 
        media_id: msg.body.mediaId
        title: msg.body.title
        description: msg.body.description.replace(ctrlUnicode,'')
    when 'news'
      unless msg.body instanceof Array
        if msg.body.title? then msg.body = [ msg.body ] else throw 'news message body must be array'
      posts = []
      for a,i in msg.body when i < 10
        throw "every news must have a title" unless a.title
        posts.push
          title: a.title.replace(ctrlUnicode,'')
          description: a.description.replace(ctrlUnicode,'')
          url: a.url
          picurl: a.picUrl
      opts[opts.msgtype] = articles: posts

  opts

# opts:
# appId,应用id
# type: 消息类型
# users/tags/departmentIds(Array/String)(Optional)
# body(object/Array/string)
Agent.prototype.sendMessage = (opts,cb) ->
  wc = this
  msgBody = {}
  try
    log "sending message",opts
    msgBody = wc.formatMessage opts
  catch err
    log "message parameters invalid",err
    return cb(err)
  prefix = config.cachePrefix or 'waas'
  limit = config.wechat.msgPerDay or 1000
  key = "#{prefix}:#{moment().format('YYYY-MM-DD')}:#{wc.identifier}"
  cache.set key,0,'EX',3600*24,'NX'
  cache.incr key, (rerr,rres) ->
    sentCount = parseInt(rres,10)
    log "#{wc.name} sent #{sentCount} messages today."
    if sentCount > limit
      log "#{wc.name} out of limit:#{limit} now:#{sentCount}"
      cache.decr key
      cb("#{wc.name} out of limit:#{limit} now:#{sentCount}")
    else
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=#{wc.accessToken}",
        msgBody
      ).once 'complete', (res) ->
        if res.errcode == 0
          log "send message ok"
          cb() 
        else
          log "failed to send message",(res.invaliduser or res.invalidparty or res.invalidtag or res.errmsg)
          cb(res.invaliduser or res.invalidparty or res.invalidtag or res.errmsg)

Agent.prototype.tags = (cb) ->
  rest.get("https://qyapi.weixin.qq.com/cgi-bin/tag/list?access_token=#{this.accessToken}").once 'complete', (res) ->
    if res.errcode == 0
      list = ({id: t.tagid, name: t.tagname} for t in res.taglist)
      cb(null,list)
    else
      cb(res.errmsg)

Agent.prototype.createTag = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/create?access_token=#{this.accessToken}",
    tagname: opts.name
  ).once 'complete', (res) ->
    if res.errcode == 0
      cb(null,{id: res.tagid, name: opts.name})
    else
      cb(res.errmsg)

Agent.prototype.renameTag = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/update?access_token=#{this.accessToken}",
    tagid: opts.id
    tagname: opts.name
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

Agent.prototype.deleteTag = (opts,cb) ->
  rest.get('https://qyapi.weixin.qq.com/cgi-bin/tag/delete',
    query: 
      access_token: this.accessToken
      tagid: opts.id
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

Agent.prototype.attachTag = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/addtagusers?access_token=#{this.accessToken}",
    userlist: if typeof opts.users == 'string' then [ opts.users ] else opts.users
    partylist: opts.departmentIds
    tagid: opts.tagId
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

Agent.prototype.detachTag = (opts,cb) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/deltagusers?access_token=#{this.accessToken}",
    userlist: if typeof opts.users == 'string' then [ opts.users ] else opts.users
    partylist: opts.departmentIds
    tagid: opts.tagId
  ).once 'complete', (res) ->
    if res.errcode == 0 then cb() else cb(res.errmsg)

# create menu
Agent.prototype.createMenu = (menu,callback) ->
  rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/menu/create?access_token=#{this.accessToken}&agentid=#{this.identifier}",
    button: menu
  ).on 'complete', (result) ->
    if result.errcode != 0
      log "failed to create menu",result.errmsg
      callback result.errmsg
    else
      log "create menu  successful",result
      callback()

Agent.prototype.usersByTag = (opts,cb) ->
  rest.get('https://qyapi.weixin.qq.com/cgi-bin/tag/get',
    query:
      access_token: this.accessToken
      tagid: opts.id
  ).once 'complete', (res) ->
    if res.errcode == 0
      list = ({ id: u.userid,name: u.name} for u in res.userlist)
      cb(null,list)
    else 
      cb(res.errmsg)

# clear menu
Agent.prototype.removeMenu = (callback) ->
  rest.get("https://qyapi.weixin.qq.com/cgi-bin/menu/delete?access_token=#{this.accessToken}&agentid=#{this.identifier}").on 'complete', (result) ->
    if result.errcode != 0
      log "failed to clear menu",result.errmsg
      callback result.errmsg
    else
      log "remove menu  successful",result
      callback()

# get menu
Agent.prototype.getMenu = (callback) ->
  rest.get("https://qyapi.weixin.qq.com/cgi-bin/menu/get",
    query:
      access_token: this.accessToken
      agentid: parseInt(this.identifier)
  ).on 'complete', (result) ->
    if result.menu?.button?
      log "get menu  successful",result.menu.button
      callback(null,result.menu.button)        
    else
      log "failed to get menu",result.errmsg
      callback(result.errmsg)

Agent.prototype.render = (view,locals,cb) ->
  file = path.join __dirname,"../views/wechat/#{view}.jade"
  jade.renderFile file,locals,cb


module.exports = Agent