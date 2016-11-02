config =
  administrators: [
    'jason'
    'jack'
    'tom'
  ]
  wechat:
    corpId: 'your-corpid'
    corpSecret: 'your-corpSecret'
    token: 'first-token'
    encodingAesKey: 'first-token'
    msgPerDay: 1000
  cachePrefix: 'waas'
  redis:
    host: "localhost"
    port: '6379'
    db: 11
  jwt:
    login:
      secret: 'iaa'
      options:
        algorithm: 'HS256'
        expiresIn: 300  # expires in 5min
    ticket:
      secret: 'client-secret'
      options:
        algorithm: 'HS256'
        expiresIn: 10
    accessToken:
      secret: 'iii'
      options:
        algorithm: 'HS256'
        expiresIn: '1 year' # expressed in seconds or an string describing a time span rauchg/ms. Eg: 60, "2 days", "10h", "7d"
    session:
      secret: 'kk'
      options:
        algorithm: 'HS512'
        expiresIn: '3 days'

module.exports = config
