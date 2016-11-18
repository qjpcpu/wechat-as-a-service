# WechatAsAService(企业微信)

目的是利用微信作为消息通知器，能做到easy to config & ready to use. 并且能够非常容易地作为依赖服务存在，比如：能够轻松集成到OP的告警系统里去。

工作场景:

公司或组织需要将微信作为消息渠道发送给企业员工一些内部通知，而内部有多个系统可能都需要使用该渠道发送消息，那么可能遇到这样的问题:

1. 运维/运营同学需要将企业注册下来的微信号凭据分享给多个子系统，有新系统接入或老系统下线，都需要运维同学去微信企业号页面修改配置；此外，如果出现凭据泄露，需要通知所有子系统修改token，除了可能出现的遗漏外，还可能造成所有子系统的服务不可用。
2. 各个内部系统均需要向公网暴露回调接口（即微信服务器的回调地址）。
3. 公司多个内部系统可能都仅仅需要一个简单的微信发送器，而如果原始地直接暴露微信接口，那么每个子系统的开发维护同学都需要开发或部署一套微信接口，浪费了程序员的智慧。修改一条格言就是`Don't repeat you guys in your scope`。
4. 微信企业号本身的权限控制比较粗放。

WechatAsAService的工作模式:

1. 运维/运营同学申请企业微信，并在微信官网配置子系统如`erp,zabbix`等agent app的回调信息，为了管理方便，回调地址最好配置为相同地址，WechatAsAService可自动区分消息转发到的app
2. 运维同学搭建WechatAsAService服务，配置其调用token及最终转发的地址。注意：每个agent app仅有一套回调地址，但可以有多个token。比如：在微信号里配置一个app叫`noah`(运维监控系统)，这个app在Waas的回调地址都配置为运维的监控系统，那么只有监控系统可以处理所有用户发送给`noah`的消息；但是，可以在Waas内为`noah`配置多个子调用token，比如监控系统本身可以调用全部的API，包括首发消息，管理人员关系等，但给某个产品线的仅开放一个最小token仅能发送消息。
3. 所有内部系统开发同学只关心一件事: 我要调用的API(通常仅一个发送消息的API)及我的token

```
这样，利用WechatAsAService，企业号管理员可以做到统一管理配置，而使用微信发消息的子系统也仅需要记住一个RESTful API而已。
```

### features:

轻依赖:

WechatAsAService仅依赖node环境和redis，甚至都不需要nginx/apache等web服务器.

易配置:


对于每个agent app，有两类处理模式可配置：

##### 1. callback类型，当收到事件或消息后，会直接POST转发到配置的url中去。该回调地址接到json消息格式类似于:

```
{ 
  msgType: 'text',
  content: 'content here',
  msgId: '4350889896202731522',
  agentId: '5',
  fromUser: 'jason-qu' 
}
```

响应的数据应该为json格式: 

```
简单回复文本内容
{ "msgType": "text","content": "响应文本内容" }
或者回复长文本内容
{ 
  "msgType": "news",
  "articles": [ 
    { 
      "title": "标题1",
      "description": "文本内容1",
      "picUrl": "图片1(非必须)",
      "url": "跳转链接1(非必须)" 
    } 
    { 
      "title": "标题2",
      "description": "文本内容2",
      "picUrl": "图片2(非必须)",
      "url": "跳转链接2(非必须)" 
    }     
  ] 
}
```

如果无须回复则直接返回空消息就可以了`{ "msgType": "text","content": "" }`

##### 2. text类型，回复words指定的消息内容，比如用户关注公众号时的欢迎语

对于消息的处理类型:

1. 对于收到的事件，可以根据事件类型回调到不同的url中去，而这也是原始微信平台所不具备的功能
2. 对于收到的文本消息，可以配置正则表达式规则，生成文本路由，也回调到不同的url或者反馈不同的消息，这也是原始微信平台所不具备的功能

单点登录:

WechatAsAService支持企业内部利用微信进行单点登录。

## 安装

WechatAsAService依赖于Node，所以请自行安装node环境，建议使用[nvm](https://github.com/creationix/nvm)安装node。

```
git clone https://github.com/qjpcpu/wechat-as-a-service.git
cd wechat-as-a-service
# 安装依赖
npm install -g coffee-script gulp pm2
npm install
# 修改编译脚本gulpfile.coffee 89行, host:为部署域名, rootDomain:为根域名
# 编译
gulp deploy
```

## 配置

### 在微信企业号页面配置回调模式
回调地址为`http://your-tifier-host/wechat/callback`

（其他略）

## 运行

waas默认监听8002端口，如果需要启动到其他端口，需要在设置环境变量`PORT`:

```
export PORT=8888
```

```
cd wechat-as-a-service
./control start  # 启动服务
./control stop   # 停止服务
./control restart # 重启服务
```

### 配置waas

#### 1.在企业号页面新建App
首先，在[微信企业号](https://qy.weixin.qq.com)页面登录配置一个新的应用`test`。

![test-index](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/test-app-index.png)

配置其回调模式
![test-callback](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/test-callback-config.png)

根据需要配置菜单

![test-menu](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/test-menu-config.png)

预览菜单

![test-menu-preview](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/test-menu-preview.png)

#### 2.配置waas App

> 在启动服务后再进入web页面配置app,需要先注释掉config.coffee里的administrators配置,NOTE:在配置自身的单点登录时,需要将负责登录的client名称设置为self,且其登录回调地址为http://exmaple.com/check_login(注意路由)

注意：waas的web管理端仅授信管理员可扫码登录，配置段位于`config.coffee`文件

```
config =
  administrators: [
    'jason'
    'jack'
    'tom'
  ]
```
在`App配置`页面配置test app:

![waas-test-app](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/waas-test-app.png)

注意这里的`ID`和微信企业号页面的`应用ID`一致,`token`和`AESKey`也必须保持一致。

配置回调模式,这里可以一起配置消息响应和事件响应:

![waas-callback-config](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/waas-callback-config.png)

当收到某种文本(支持正则表达式)后，可以直接回复文本内容或将收到的消息转发到某个回调地址；

当接受到某个事件，也可以回复指定文本，或将事件转发到某个回调地址；

如果不需要进行响应，可以不配置。

一个waas `App`需要对应配置一个Client,如果不需要进行单点登录，这里的登录回调地址可以留空:

![waas-test-client](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/waas-test-client.png)

如果客户端调用waas API，则需要在client配置页生成token:

![get-client-token](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/get-client-token.png)


### 客户token配置

配置已迁移到web页面

### 调用waas

所有api调用必须带上上一步配置的token，调用规则为:

```
GET/POST/PUT/DELETE  /api-uri?accessToken=YOUR_TOKEN
```

如，客户token是`NDdkMWU3MTAtODQ2NS0`,发送给用户jason一条简单消息:

```
curl http://127.0.0.1:8002/users/send?accessToken=NDdkMWU3MTAtODQ2NS0 -d body=hello -d users=jason
```

发送给具有某个角色标签`god`的所有用户一条消息:

```
curl http://127.0.0.1:8002/roles/god/send?accessToken=NDdkMWU3MTAtODQ2NS0 -d body=hello
```

发送一条长消息给jason和link:

```
curl -H "Content-Type: application/json" -X POST -d '{"users":["jason","link"],"body":{"title":"subject1","description":"this is a very long message","url":"http://www.baidu.com","picUrl":"http://i5.hexunimg.cn/2016-06-29/184643130.jpg"},"type":"news"}'  http://127.0.0.1:8002/users/send?accessToken=NDdkMWU3MTAtODQ2NS0
```

## 单点登录

### 单点登录配置

```
<div id="login"></div>
<script src="https://wechat.example.com/assets/scripts/lander.js"></script>
<script type="text/javascript">
$( document ).ready(function() {
  var lander = new Lander({
    clientId: '87576cd0-b399-11e5-822e-73276d944134',
    redirectTo: 'http://localhost/callback', //调试时使用localhost，正式环境不需要配置
    info: 'LOVE'   //可选
  });
  lander.on('qrcode',function(data,cb){
    console.log(data.qrimage);
    cb()
    });
  lander.login();
});
</script>
```

首先，需要在微信公众号某个app配置一个扫描二维码的菜单，建议新建独立app专门作为登录app。将该app的回调模式=>自定义菜单配置为:

![menu config](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/menu-config.png)

注意菜单类型必须为`扫描推事件(弹框)`。（当然回调模式也需要正确配置，不再赘述）

### 登录示例

比如内部系统`Test`需要使用单点登录:

如果waas的域名为`http://wcn.com`,`Test`系统需要引导用户到`http://wcn.com/?id=7fa8ab90-8462-11e5-92ac-717b74321647&redirect_uri=http://test.com`登录。

其中，`id`为上一步生成的id,`redirect_uri`是回调地址。

用户到`http://wcn.com/?id=7fa8ab90-8462-11e5-92ac-717b74321647&redirect_uri=http://test.com/callback`看到如下的页面:

![login page](https://raw.githubusercontent.com/qjpcpu/wechat-as-a-service/master/snapshots/login.png)

用户使用企业号配置的对应app扫码即可登录，成功登录后会回调到:

```
http://test.com/callback/?ticket=DkwMS0xMWU1LWJiMjMtYWRjZ
```

`Test`系统获取到这个ticket后就到Waas进行验证，获取用户信息。

```
POST http://wcn.com/validate?accessToken=NDdkMWU3MTAtODQ2NS0xMWU1LWFhYTItZDNmMDAwOTQ4Y2Yw
post请求数据为:
{
  "ticket": "DkwMS0xMWU1LWJiMjMtYWRjZ"
}
```

> 注意:
> waas设想的场景为内部系统单点登录，并没有对回调地址做限制。

## API列表

####  POST /exchange_token
更换客户端token

request:

|名称|类型|类别|举例|可选/必须|
|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'update token ok',token: new-key }`|
|失败| HTTP 403|

####  GET /users
获取企业用户

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|departmentId|Integer|query parameter| 1|可选|部门id|
|detail|String|query parameter|yes|可选|显示用户详情，默认为no|
|recursive|String|query parameter|yes|可选|是否获取子部门人员，默认yes|
|status|String|query parameter|all|可选，获取用户状态all/watched/disabled/unwatched|

response:

|结果|返回|
|----|----|
|成功|用户列表|
|失败| 空|

####  POST /users
获取企业用户

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|email|String|payload|jason@gmail.com|必须|用户邮箱地址|
|id|String|payload|jason|可选|默认为用户邮箱前缀|
|mobile|String|payload|13922221111|可选|用户手机号|
|name|String|payload|Jack Spanrrow|可选|用户姓名|
|department|Array|payload|[1,2]|可选|用户所属部门|
|position|String|payload|DevOps|可选|用户职位|
|gender|String|payload|male|可选|用户性别mail或female|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败| HTTP 403|

####  POST /users/send
发送消息

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|users|String或Array|payload|"jason"或["jason","link"]|users/tagIds/departmentIds必须包含一个|收件人id(列表)|
|tagIds|String或Array|payload|2或[1,2]|users/tagIds/departmentIds必须包含一个|收件人标签id(列表)|
|departmentIds|String或Array|payload|2或[1,2]|users/tagIds/departmentIds必须包含一个|收件人部门id(列表)|
|type|String|payload|text|可选|默认为text,其他值为news|
|body|String或object|payload|`{"title":"subject1","description":"this is a very long message"}`或`"content here"`,如果一次发送多条新闻消息则消息体为`[{"title":"subject1","description":"content1"},{"title":"subject2","description":"content2"}]`|可选|消息体|


response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败| HTTP 403|

####  GET /users/:userId
获取用户

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|userId|String|path parameter|jason|必须|用户ID|

response:

|结果|返回|
|----|----|
|成功|用户信息|
|失败| HTTP 403|

####  PUT /users/:userId
修改用户

request: 参数同创建用户


response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败| HTTP 403|

####  GET /users/:userId/invite
邀请用户关注

request: 

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|userId|String|path parameter|jason|必须|用户ID|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败| HTTP 403|

####  DELETE /users/:userId
删除用户

request: 

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|userId|String|path parameter|jason|必须|用户ID|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败| HTTP 403|

####  POST /users/:userId/send
发送消息

request: 

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|userId|String|path parameter|jason|必须|用户ID|
|type|String|payload|text|可选|默认为text,其他值为news|
|body|String或object|payload|`{"title":"subject1","description":"this is a very long message"}`或`"content here"`,如果一次发送多条新闻消息则消息体为`[{"title":"subject1","description":"content1"},{"title":"subject2","description":"content2"}]`|可选|消息体|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败| HTTP 403|

#### GET /roles
获取角色标签

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|

response:

|结果|返回|
|----|----|
|成功|角色标签列表|
|失败| 空|

#### POST /roles
创建新角色标签

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|name|String|payload|op|必须|角色名|

response:

|结果|返回|
|----|----|
|成功|新角色标签|
|失败|HTTP 403|

#### DELETE /roles/:id
删除角色标签

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|1|必须|角色id|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败|HTTP 403|

#### GET /roles/:id/users
获取拥有该标签的用户

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|1|必须|角色id|

response:

|结果|返回|
|----|----|
|成功|用户列表|
|失败|HTTP 403|

#### POST /roles/:id/attach
为用户添加角色标签

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|1|必须|角色id|
|users|Array或String|payload|'jason'|必须|用户ID列表|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败|HTTP 403|

#### POST /roles/:id/detach
删除用户角色标签

request同上

#### GET /departments
获取部门列表

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|query parameter|1|可选|部门id|

response:

|结果|返回|
|----|----|
|成功|部门列表|
|失败|空|

#### POST /departments
创建部门

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|name|String|payload|'TechCenter'|必须|部门名称|
|parentId|Integer|payload|1|可选|父部门id|

response:

|结果|返回|
|----|----|
|成功|新部门信息|
|失败|HTTP 403|

#### PUT /departments/:id
修改部门信息

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|3|必须|部门ID|
|name|String|payload|'TechCenter'|可选|部门名称|
|parentId|Integer|payload|1|可选|父部门id|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败|HTTP 403|

#### GET /departments/:id/users
获取部门员工

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|1|必须|角色id|
|recursive|String|query parameter|yes|可选|是否获取子部门员工，默认yes|

response:

|结果|返回|
|----|----|
|成功|用户列表|
|失败|HTTP 403|


#### DELETE /departments/:id/:userId
从部门移除员工

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|1|必须|角色id|
|userId|String|path parameter|jason|必须|用户id|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败|HTTP 403|

#### POST /departments/:id/:userId
将员工添加进部门

request:

|名称|类型|类别|举例|可选/必须|描述|
|----|----|----|----|----|----|
|accessToken|String|query parameter|NDdkMWU3MTAtODQ2NS0|必须|客户系统token|
|id|String|path parameter|1|必须|角色id|
|userId|String|path parameter|jason|必须|用户id|

response:

|结果|返回|
|----|----|
|成功|`{ message: 'OK' }`|
|失败|HTTP 403|
