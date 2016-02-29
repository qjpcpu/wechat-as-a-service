expect = require 'expect.js'
async = require 'async'
Agent = require '../models/agent'

describe 'Agent', ->
  agent = undefined
  before (done) ->
    Agent.find limit:1, (err,agents) ->
      agent = agents[0]
      done()
  
  describe "#fetchAccessToken", ->
    it "should get access_token", (done) ->
      agent.fetchAccessToken (err,token) ->
        expect(err).to.be(null)
        expect(token.length).to.be.greaterThan 1
        done()

  context 'have valid access token', ->
    before (done) ->
      agent.fetchAccessToken (err,token) ->
        done()

    describe '#departments', ->
      it 'should control departments', (done) ->
        async.waterfall [
          (cb) ->
            agent.departments {},(err,list) ->
              expect(err?).to.eql false
              cb(err,list)
          (list,cb) ->
            testDept = (dept for dept in list when dept.name == 'test')[0]
            if testDept
              cb(null,testDept)
            else
              agent.createDepartment name: 'test',(err,dept) ->
                expect(err?).to.eql false
                cb(err,dept)
          (testDept,cb) ->
            agent.updateDepartment id: testDept.id,name: "#{testDept.name}_alias", (err) ->
              expect(err?).to.eql false
              cb(err,testDept)
          (testDept,cb) ->
            agent.deleteDepartment id: testDept.id, (err) ->
              expect(err?).to.eql false
              cb(err)              
        ], (err) ->
          done()

    describe '#createMenu', ->
      it 'should create menu', (done) ->
        this.timeout 10000
        menu = [    
          {
            'type': 'click'
            'name': '主菜单A'
            'key': 'level1_menu'
          }
          {
            'name': '主菜单B'
            'sub_button': [
              {
                'type': 'view'
                'name': '百度一下'
                'url': 'http://www.baidu.com/'
              }
              {
                'type': 'click'
                'name': '赞一下我'
                'key': 'star_menu'
              }
            ]
          }
        ]
        async.waterfall [
          (cb) ->
            agent.createMenu menu, (err) ->
              expect(err?).to.eql false
              setTimeout (-> cb(err)),1000
          (cb) ->
            agent.getMenu (err,m) ->
              expect(err?).to.eql false
              cb(err)
          (cb) ->
            agent.removeMenu (err) ->
              expect(err?).to.eql false
              setTimeout (-> cb(err)),1000
          (cb) ->
            agent.getMenu (err,m) ->
              expect(err).to.eql 'menu no exist'
              cb(err == 'menu no exist')                   
        ], (err) ->
          done()

    describe '#users', ->
      it 'should control users', (done) ->
        async.waterfall [
          (cb) ->
            agent.users status: 'all',detail: true, (err,list) ->
              expect(err?).to.eql false
              cb(err,list)
          (list,cb) ->
            userInfo = (u for u in list when u.id == 'fake_user_id')[0]
            if userInfo
              cb(null,userInfo)
            else
              userInfo =
                id: 'fake_user_id' # required
                mobile: '13966668888' # userInfo must contain ether mobile or email
                email: 'fake@example.com' # userInfo must contain ether mobile or email
                name: 'fake_name'
                sex: 'male' # or female
                departmentIds: [1]
                position: 'CEO'
              agent.createUser userInfo, (err) ->
                expect(err?).to.eql false
                cb(err,userInfo)
          (userInfo,cb) ->
            agent.updateUser id: userInfo.id,name: "#{userInfo.name}_new",state: 'disable', (err) ->
              expect(err?).to.eql false
              cb(err,userInfo)
          (userInfo,cb) ->
            agent.user id: userInfo.id, (err,user) ->
              expect(err?).to.eql false
              cb(err,user)
          (userInfo,cb) ->
            agent.deleteUser id: userInfo.id, (err) ->
            # or
            # agent.deleteUser id: [userInfo.id], (err,user) ->
              expect(err?).to.eql false
              cb(err)          
        ], (err) ->
          done()

    describe '#roles', ->
      it 'should control roles', (done) ->
        async.waterfall [
          (cb) ->
            agent.tags (err,list) ->
              expect(err?).to.eql false
              cb(err,list)
          (list,cb) ->
            role = (r for r in list when r.name == 'my_role')[0]
            if role
              cb(null,role)
            else
              agent.createTag name: 'my_role', (err,tag) ->
                expect(err?).to.eql false
                cb(err,tag)
          (role,cb) ->
            agent.renameTag id: role.id,name: "new_role_name", (err) ->
              expect(err?).to.eql false
              cb(err,role)
          (role,cb) ->
            agent.deleteTag id: role.id, (err) ->
              expect(err?).to.eql false
              cb(err)
        ], (err) ->
          done()

    describe '#attach role to/from user', ->
      it 'should attach roles', (done) ->
        this.timeout 10000
        async.waterfall [
          (cb) ->
            userInfo = id: 'attach_user', email: 'attuser@example.com'
            agent.createUser userInfo, (err) ->
              expect(err?).to.eql false
              cb(err,userInfo)
          (user,cb) ->
            agent.createTag name: 'my_att_role', (err,role) ->
              expect(err?).to.eql false
              cb(err,user,role)              
          (user,role,cb) ->
            agent.attachTag users: [user.id],tagId: role.id, (err) ->
              expect(err?).to.eql false
              cb(err,user,role)
          (user,role,cb) ->
            agent.usersByTag id: role.id, (err,list) ->
              expect(err?).to.eql false
              expect((u.id for u in list when u.id == user.id)[0]).to.eql 'attach_user'
              cb(err,user,role) 
          (user,role,cb) ->
            agent.detachTag users: [user.id],tagId: role.id, (err) ->
              expect(err?).to.eql false
              cb(err,user,role)
          (user,role,cb) ->
            agent.deleteTag id: role.id, (err) ->
              expect(err?).to.eql false
              agent.deleteUser id: user.id, (err) ->
                expect(err?).to.eql false
                cb(err)              
        ], (err) ->
          done()

    describe '#send message', ->
      it 'should send message', (done) ->
        this.timeout 10000
        userId = 'replace_by_your_available_user_id' # make sure the userId is watch this wechat, otherwise the message can't be sent
        textMsg = 
          users: [ userId ]
          # users: 'userId'
          # users: 'userId1|userId2'
          # users: '@all'
          # tagIds: 'tagId1|tagId2'
          # tagIds: ['tagId1','tagId2']
          type: 'text'
          body: 'message content here'
        newsMsg = 
          users: [ userId ]
          # users: 'userId'
          # users: 'userId1|userId2'
          # users: '@all'
          # tagIds: 'tagId1|tagId2'
          # tagIds: ['tagId1','tagId2']
          type: 'news'
          body: [
            {
              title: 'news1'
              description: 'news1 content'
              url: 'http://www.baidu.com'
              picUrl: 'https://ss0.bdstatic.com/5aV1bjqh_Q23odCf/static/superman/img/logo/logo_redBlue.png'
            }
            {
              title: 'news2'
              description: 'news2 content'
            }            
          ]
        newsMsg2 = 
          users: [ userId ]
          # users: 'userId'
          # users: 'userId1|userId2'
          # users: '@all'
          # tagIds: 'tagId1|tagId2'
          # tagIds: ['tagId1','tagId2']
          type: 'news'
          body: 
            title: 'news 3'
            description: 'news3 content'
        
        async.parallel [
          (cb) ->
            agent.sendMessage textMsg, (err) ->
              expect(err?).to.eql false
              cb(err)
          (cb) ->
            agent.sendMessage newsMsg, (err) ->
              expect(err?).to.eql false
              cb(err)
          (cb) ->
            agent.sendMessage newsMsg2, (err) ->
              expect(err?).to.eql false
              cb(err)              
        ], (err) ->
          done()       