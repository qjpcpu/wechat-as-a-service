CrossStorage = require 'cross-storage'
rootDomain = '{{rootDomain}}$'

CrossStorage.CrossStorageHub.init [
  { 
  	origin: /localhost/
  	allow: ['get','set','del']
  }
  {
  	origin: new RegExp(rootDomain)
  	allow: ['get','set','del']
  }
]