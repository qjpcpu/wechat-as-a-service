gulp = require 'gulp'
bowerSrc = require 'gulp-bower-src'
coffee = require 'gulp-coffee'
insert = require 'gulp-insert'
mergeStream = require 'merge-stream'
fs = require 'fs'
mocha = require 'gulp-mocha'
cssmin = require 'gulp-cssmin'
uglyfly = require 'gulp-uglyfly'
gls = require 'gulp-live-server'
runSequence = require 'run-sequence'
del = require 'del'
browserify = require 'browserify'
coffeeify = require 'coffeeify'
gutil = require 'gulp-util'
buffer = require 'vinyl-buffer'
source = require 'vinyl-source-stream'
uglify = require 'gulp-uglify'
sourcemaps = require 'gulp-sourcemaps'
globby = require 'globby'
rename = require 'gulp-rename'
eventStream = require 'event-stream'
gbuild = require 'gulp-build'
watchify = require 'watchify'


browserifyCoffee = (opts,done) ->
  globby(opts.src).then (entries) ->
    tasks = entries.map (entry) ->
      b = browserify
        entries: entry
        extensions: ['.coffee']
        debug: true
        transform: coffeeify,
          bare: false
          header: true
      b = watchify b if opts.watch
      genBundle = ->
        b.bundle()
          .pipe(source(entry))
          .pipe(rename(extname: '.js',dirname: ''))
          .pipe(buffer())
          .pipe(sourcemaps.init({loadMaps: true}))
          .pipe(uglify())
          .on('error', gutil.log)
          .pipe(gulp.dest(opts.dist))
      b.on 'update',genBundle
      b.on 'log',gutil.log
      genBundle()
    eventStream.merge(tasks).on('end', done)
  null


gulp.task 'clean', ->
  del [
    'public/assets'
  ]

gulp.task 'default', (cb) ->
  cb()

gulp.task 'assetsCoffee', (cb) ->
  browserifyCoffee src: ['./assets/scripts/controllers/*.coffee'],dist: './public/assets/scripts',cb

gulp.task 'assets', ['assetsCoffee'], ->
  cssList = [
    'assets/stylesheets/**/*'
    'node_modules/bootstrap/dist/css/bootstrap.min.css'
    'node_modules/toastr/build/toastr.css'
  ]
  cssAssets = gulp.src(cssList)
    .pipe cssmin()
    .pipe gulp.dest('public/assets/stylesheets')
  favicon = gulp.src('assets/favicon.ico').pipe gulp.dest('public')
  mergeStream cssAssets,favicon

# run test task
gulp.task 'test',  ->
  gulp.src('test/*.coffee', {read: false})
    .pipe coffee()
    .pipe(mocha({reporter: 'nyan'}))

# build all
gulp.task 'build', (cb) ->
  runSequence 'clean',['assets'], cb

gulp.task 'deploy', ['build'], ->
  gulp.src ['./public/assets/scripts/lander.js','./public/assets/scripts/index.js','./public/assets/scripts/local_talk.js']
    .pipe gbuild(host: 'https://wechat.pf.tap4fun.com',rootDomain: 'tap4fun.com')
    .pipe gulp.dest('./public/assets/scripts/')

# start serve
gulp.task 'serve', ->
  browserifyCoffee src: ['./assets/scripts/controllers/*.coffee'],dist: './public/assets/scripts',watch: true, -> true
  server = gls.new 'bin/www'
  server.start()
  gulp.watch ['./app.coffee','./routes/*.coffee','./models/*.coffee','./views/**/*.jade'], (file) ->
    console.log 'Reload server'
    server.notify.apply server, [file]    