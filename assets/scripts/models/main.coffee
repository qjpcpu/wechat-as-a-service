$ = require 'jquery-browserify'
bootstrap = require 'bootstrap'
$ ->
  currentPath = window.location.pathname
  while currentPath.length > 0
    found = false
    $('li.first-nav a').each (i,v) ->
      if $(v).attr('href') == currentPath
        found = true
        $(v).parent().addClass 'active'
      else
        $(v).parent().removeClass 'active'
    break if found
    break if currentPath == '/'
    currentPath = currentPath.replace /\/[^\/]+$/,''

module.exports = 'main'
