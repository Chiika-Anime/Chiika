srcDir      = 'src'
serveDir    = '.serve'
distDir     = 'dist'
releaseDir  = 'release'
rootDir = '.'

# ---------------------------
#
# ---------------------------

packageJson = require('./package.json')

gulp = require('gulp')
fs = require('fs')
del = require('del')
argv = require('yargs').argv
path = require 'path'
mainBowerFiles = require('main-bower-files')
ep = require('electron-prebuilt')

packager = require('electron-packager')

# gulps
sourcemaps = require "gulp-sourcemaps"
plumber = require "gulp-plumber"



Compile_scss_files_with_sourcemaps = () ->
  gulp.task 'compile:styles', () ->

    sass = require "gulp-sass"

    gulp.src([srcDir + '/styles/**/*.scss'])
      .pipe(sourcemaps.init())
      .pipe(sass())
      .pipe(sourcemaps.write('.'))
      .pipe(gulp.dest(serveDir + '/styles'))

Inject_css___compiled_and_depedent___files_into_html = () ->
  gulp.task 'inject:css', ['compile:styles'], (done) ->

    inject = require "gulp-inject"
    concat = require "gulp-concat"
    gulpif = require "gulp-if"
    gulpIgnore = require 'gulp-ignore'
    debug = require 'gulp-debug-streams'


    themeToBuild = 'Light'
    files = mainBowerFiles('**/*.css').concat([serveDir + '/styles/**/*.css'])

    options =
      relative: true
      ignorePath: ['../../.serve', '..']
      addPrefix: '..'

    stream = gulp.src(mainBowerFiles('**/*.js'))
                .pipe(concat('bundleJs.js'))
                .pipe(gulp.dest(serveDir))

    files = files.concat([serveDir + '/bundleJs.js' ])

    ignoreThemeFile = 'Light'
    if themeToBuild == 'Light'
      ignoreThemeFile = 'Dark'

    condition = "#{ignoreThemeFile}Theme.css"

    stream.on 'end', =>
      str = gulp.src(srcDir + '/**/*.html')
          .pipe(inject(gulp.src(files).pipe(gulpIgnore.exclude(condition)),options))
          .pipe(gulp.dest(serveDir))
      str.on 'end', done
    dummy = 42


Copy_assets = () ->
  gulp.task 'misc', () ->
    debug  = require 'gulp-debug-streams'

    gulp.src(srcDir + '/assets/**/*')
      .pipe(gulp.dest(serveDir + '/assets'))


Copy_scripts = () ->


Copy_vendor = () ->
  gulp.task 'copy:vendor', () ->
    gulp.src(rootDir + '/vendor/**/*')
    .pipe(gulp.dest(serveDir + '/vendor'))
    .pipe(gulp.dest(distDir + '/vendor'))

Incremental_compile_cjsx_coffee_files_with_sourcemaps = () ->
  gulp.task 'compile:scripts:watch', (done) ->

    watch = require "gulp-watch"
    coffee = require "gulp-coffee-react"

    gulp.src('src/**/*.{cjsx,coffee}')
      #.pipe(watch('src/**/*.{cjsx,coffee}', {verbose: true}))
      .pipe(plumber())
      .pipe(sourcemaps.init())
      .pipe(coffee())
      .pipe(sourcemaps.write('.'))
      .pipe(gulp.dest(serveDir))
      .on('end',done)
    gulp.src('src/**/*.{cjsx,coffee}')
      .pipe(watch('src/**/*.{cjsx,coffee}', {verbose: true}))
      .pipe(plumber())
      .pipe(sourcemaps.init())
      .pipe(coffee())
      .pipe(sourcemaps.write('.'))
      .pipe(gulp.dest(serveDir))

    test = 42



Compile_scripts_for_distribution = () ->
  gulp.task 'compile:scripts', () ->

    coffee = require "gulp-coffee-react"

    gulp.src('src/**/*.{cjsx,coffee}')
      .pipe(plumber())
      .pipe(coffee())
      .pipe(gulp.dest(distDir))

    gulp.src(serveDir + '/bundleJs.js')
        .pipe(gulp.dest(distDir))


  gulp.task 'compile:scripts:not:watch', () ->
    coffee = require "gulp-coffee-react"
    gulp.src('src/**/*.{cjsx,coffee}')
      .pipe(plumber())
      .pipe(coffee())
      .pipe(gulp.dest(serveDir))

    # gulp.src('src/*.js')
    #     .pipe(gulp.dest(distDir))
    # gulp.src('src/browser/tools/src/*.js')
    #     .pipe(gulp.dest(distDir))
    # gulp.src(serveDir + '/chiika.js')
    #     .pipe(gulp.dest(distDir))

Inject_renderer_bundle_file_and_concatnate_css_files = () ->
  gulp.task 'html', ['inject:css'], () ->

    useref = require "gulp-useref"
    gulpif = require "gulp-if"
    minify = require "gulp-minify-css"

    debug  = require 'gulp-debug-streams'

    assets = useref.assets({searchPath: ['bower_components', serveDir + '/styles']})


    gulp.src(serveDir + '/static/*.html')
      .pipe(debug('First'))
      .pipe(assets)
      .pipe(debug('2'))
      .pipe(assets.restore())
      .pipe(debug('3'))
      .pipe(useref())
      .pipe(gulp.dest(distDir + "/static"))

Copy_fonts_file = () ->

  flatten = require "gulp-flatten"

  # You don't need to copy *.ttf nor *.svg nor *.otf.
  gulp.task 'copy:fonts', () ->
    gulp.src('bower_components/**/fonts/*.woff')
      .pipe(flatten())
      .pipe(gulp.dest(distDir + '/fonts'))

    gulp.src('bower_components/**/fonts/*.woff2')
      .pipe(flatten())
      .pipe(gulp.dest(distDir + '/fonts'))


Write_a_package_json_for_distribution = () ->
  gulp.task 'packageJson', (done) ->

    _ = require('lodash')

    json = _.cloneDeep(packageJson)
    json.main = './main_process/chiika.js'
    fs.writeFile(distDir + '/package.json', JSON.stringify(json), () -> done())

Package_for_each_platforms = () ->
  success = =>
    console.log "Packaging success"
  error = (error) =>
    console.log error


  gulp.task 'package:win32', ['build'], (done) ->
    arch = 'x64'
    platform = 'win32'
    options =
      dir: distDir
      name: 'Chiika'
      arch: arch
      platform: platform
      out: releaseDir + '/' + platform + '-' + arch
      version: '1.3.1'
      asar: false
      icon: './resources/windows/icon.ico'
    options['version-string'] = {
      'CompanyName': 'arkenthera',
      'LegalCopyright': 'Whatever',
      'FileDescription' : 'Chiika',
      'OriginalFilename' : 'Chiika.exe',
      'FileVersion' : '0.0.2',
      'ProductVersion' : '0.0.2',
      'ProductName' : 'Chiika',
      'InternalName' : 'Chiika.exe'
    }

    packager options,error


gulp.task 'ci:win32', () ->
  electronInstaller = require('electron-winstaller')
  resultPromise = electronInstaller.createWindowsInstaller({
    appDirectory: './release/win32-x64/Chiika-win32',
    outputDirectory: './release/installer',
    description: 'Ultimate Anime/Manga scrobbler',
    title: "chiika",
    authors: 'arkenthera',
    exe: 'Chiika.exe',
    iconUrl: "#{process.cwd()}/resources/windows/icon.ico",
    noMsi: true,
    loadingGif: './src/assets/installer.gif',
    remoteReleases: 'https://chiika.herokuapp.com/update/win32/0.0.1'
    setupExe: 'Chiika-Windows-Installer.exe' })

  success = () =>
    console.log "Installer for has been created"
  error = (e) =>
    console.log "Whoops... #{e.message}"

  resultPromise.then(success,error)

gulp.task 'ci:linux', () ->
  installer = require 'electron-installer-debian'
  options =
    src: 'release/linux-x64/Chiika-linux',
    dest: 'dist/installers/',
    arch: 'amd64'

  installer options, (err) =>
    if err
      console.log err
      process.exit(1)
    console.log "Created deb package"

do Your_Application_will_ = () ->
  Compile_scss_files_with_sourcemaps()
  Compile_scripts_for_distribution()
  Inject_css___compiled_and_depedent___files_into_html()
  Copy_assets()
  Copy_vendor()
  Copy_scripts()
  Incremental_compile_cjsx_coffee_files_with_sourcemaps()
  Compile_scripts_for_distribution()
  Inject_renderer_bundle_file_and_concatnate_css_files()
  Copy_fonts_file()
  Write_a_package_json_for_distribution()
  Package_for_each_platforms()


  gulp.task('build', ['html', 'compile:scripts', 'packageJson', 'copy:fonts', 'misc','copy:vendor'])
  gulp.task('test', ['inject:css', 'compile:scripts:not:watch', 'compile:styles', 'misc','copy:vendor'])
  gulp.task 'serve', ['inject:css', 'compile:scripts:watch', 'compile:styles', 'misc'], () ->
    development = null
    development = Object.create( process.env );
    development.CHIIKA_ENV = 'debug';
    if argv.pls
      development.Show_CA_Debug_Tools = 'yeah'
    development.version = packageJson.version
    development.DEV_MODE = true
    development.RUNNING_TESTS = false
    development.SCRIPTS_PATHS = [ path.join(__dirname,'scripts')]

    if argv.clean
      rimraf = require 'rimraf'
      rimraf path.join(process.env.APPDATA,'chiika'), { }, ->
        console.log "Removed Chiika folder"

    electron = require('electron-connect').server.create({
        electron:ep,
        spawnOpt: {
          command: "--debug=5858"
          env:development || 'nope'
        }
      })
    electron.start([], () => {})
    gulp.watch(['bower.json', srcDir + '/index.html',srcDir + '/MyAnimeListLogin.html'], ['inject:css'])
    gulp.watch([srcDir + '/styles/*.scss'],['inject:css'])
    gulp.watch([serveDir + '/styles/**/*.css', serveDir + '/**/*.html', serveDir + '/**/*.js'], electron.reload)
    gulp.watch([serveDir + '/main_process/chiika.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/api-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/ipc-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/chiika-public.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/database-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/db-users.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/db-custom.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/db-interface.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/db-ui.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/db-view.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/request-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/settings-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/window-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/media-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/media-detect-win32-process.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/ui-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/view.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/ui-tabView.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/utility.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/view-manager.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/app-delegate.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/notification-bar.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/media-recognition.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/media-library-process.js'], electron.restart)
    gulp.watch([serveDir + '/main_process/browser-extension-manager.js'], electron.restart)

  gulp.task 'clean', (done) ->
    del [serveDir, distDir, releaseDir], () -> done()
  gulp.task('default', ['build'])
  if taskListing = require "gulp-task-listing" then gulp.task "help", taskListing
