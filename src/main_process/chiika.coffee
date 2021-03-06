#----------------------------------------------------------------------------
#Chiika
#Copyright (C) 2016 arkenthera
#This program is free software; you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation; either version 2 of the License, or
#(at your option) any later version.
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#Date: 23.1.2016
#authors: arkenthera
#Description:
#----------------------------------------------------------------------------
#
#
#--------------------
#
#--------------------


{app,BrowserWindow}               = require 'electron'
path                              = require 'path'

{Emitter,Disposable}              = require 'event-kit'
string                            = require 'string'


Logger                            = require './logger'
#
APIManager                        = require './api-manager'
DbManager                         = require './database-manager'
RequestManager                    = require './request-manager'
SettingsManager                   = require './settings-manager'
WindowManager                     = require './window-manager'
IpcManager                        = require './ipc-manager'
ShortcutManager                   = require './shortcut-manager'
MediaManager                      = require './media-manager'
Parser                            = require './parser'
UIManager                         = require './ui-manager'
ViewManager                       = require './view-manager'
ChiikaPublicApi                   = require './chiika-public'
Utility                           = require './utility'
AppOptions                        = require './options'
AppDelegate                       = require './app-delegate'
NotificationBar                   = require './notification-bar'
UpdateManager                     = require './update-manager'
BrowserExtensionManager           = require './browser-extension-manager'


process.on 'exit', (code) ->
  console.log "Exiting.. #{code}"

process.on 'uncaughtException',(err) ->
  # chiika.logger.log 'error', 'Fatal uncaught exception crashed cluster', err, (err, level, msg, meta) =>
  #   process.exit(1);
  console.log err
  # Show a somewhat easily readable text error
  if err && err.stack?
    error = err.stack.split("\n")
    for i in [0...5]
      line = error[i]
      line = string(line).trimLeft().s

      if i > 0
        fileLine = line.substring(line.lastIndexOf('\\') + 1, line.length - 1)
        errorFunction = line.substring(3,line.indexOf('('))
        chiika.logger.error errorFunction + " - " + fileLine
      else
        chiika.logger.error line
  else
    chiika.logger.error("Hmm....")
    chiika.logger.error(err)


module.exports =
class Application
  devMode: false
  runningTests: false
  ready: false

  scriptsPaths: []



  #
  # Entry point of Chiika
  #
  constructor: () ->
    if require('electron-squirrel-startup')
      return

    global.chiika          = this
    global.__base          = process.cwd() + '/'
    global.mainProcessHome = __dirname


    process.env.CHIIKA_APPDATA = app.getPath('appData')
    process.env.CHIIKA_RESOURCES_SRC = path.join(__dirname,'..','assets')

    module.paths.push(path.resolve('node_modules'))
    module.paths.push(path.resolve('../node_modules'))
    module.paths.push(path.resolve(__dirname, '..', '..', '..', 'resources', 'app', 'node_modules'))
    module.paths.push(path.resolve(__dirname, '..', '..', '..', 'resources', 'app.asar', 'node_modules'))

    if process.env.DEV_MODE
      scriptRequirePath = path.join(process.cwd(),'node_modules')
    else
      scriptRequirePath = path.join(__dirname,'..','node_modules')

    global.scriptRequire = (name) ->
      require(path.join(scriptRequirePath,name))

    @chiikaHome         = path.join(app.getPath('appData'),"chiika")

    @logger             = new Logger("verbose").logger
    global.logger       = @logger #Share with renderer

    chiika.logger.info "#{scriptRequirePath} Global Script Require path"


    @emitter            = new Emitter
    @utility            = new Utility()
    @settingsManager    = new SettingsManager()
    @apiManager         = new APIManager()
    @dbManager          = new DbManager()
    @requestManager     = new RequestManager()
    @parser             = new Parser()
    @viewManager        = new ViewManager()
    @uiManager          = new UIManager()
    @mediaManager       = new MediaManager()
    @chiikaApi          = new ChiikaPublicApi()
    @windowManager      = new WindowManager()
    @appDelegate        = new AppDelegate()
    @ipcManager         = new IpcManager()
    @shortcutManager    = new ShortcutManager()
    @notificationBar    = new NotificationBar()
    @updateManager      = new UpdateManager()
    @browserManager     = new BrowserExtensionManager()

    @ipcManager.handleEvents()

    app.commandLine.appendSwitch('--disable-2d-canvas-image-chromium');
    app.commandLine.appendSwitch('--disable-accelerated-2d-canvas');
    app.commandLine.appendSwitch('--disable-gpu');
    app.commandLine.appendSwitch('--enable-experimental-web-platform-features')
    app.commandLine.appendSwitch('--version-string.FileDescription=test')

    @appDelegate.run()

    @appDelegate.ready =>
      @mediaManager.initialize()
      @notificationBar.create()

      @emitter.on 'updater-ready', =>
        @dbManager.onLoad().then =>
          @run()
          @handleEvents()

      @updateManager.check()


  run: ->
    #
    #
    #
    #
    userCount     = @dbManager.usersDb.users.length
    viewConfig    = @settingsManager.readConfigFile('view')
    viewCount     = 0
    if viewConfig?
      viewCount     = @settingsManager.readConfigFile('view').views.length



    chiika.logger.verbose("User count #{userCount}")
    chiika.logger.verbose("View count #{viewCount}")

    # If there are no users and view data
    # Compile scripts first
    # Because if there are no UI data, UI Manager will ask scripts to create UI data, so we need scripts compiled
    #
    if userCount == 0 && viewCount == 0
      @apiManager.preCompile().then =>
        @apiManager.postCompile()

        @viewManager.preload()
                  .then =>
                    chiika.logger.verbose("Preloading complete!")
                    @apiManager.postInit()
                    chiika.windowManager.createLoginWindow()


    if userCount == 0 && viewCount > 0
      @apiManager.preCompile().then =>
        @apiManager.postCompile()

        @viewManager.preload().then =>
          chiika.logger.verbose("Preloading complete!")

          @apiManager.postInit()
          chiika.windowManager.createLoginWindow()


    if userCount > 0 && viewCount > 0
      # If there are no UI items
      # compile scripts first
      # if there are UI items,
      # preload them first so when script is ready, they can access them right of the bat
      # after preload and script compile, check if the views need update
      # if they do, call view-update event so script can respond
      #chiika.windowManager.createMainWindow()
      @apiManager.preCompile().then =>
        @apiManager.postCompile()


        @viewManager.preload().then =>
          chiika.logger.verbose("Preloading UI complete!")
          @apiManager.postInit()

          chiika.windowManager.createMainWindow()



  #
  #
  #
  handleEvents: ->
    @emitter.on 'shortcut-pressed', (key) =>
      # Inform subsystems so they do their thing
      @ipcManager.systemEvent('shortcut-pressed',key)

    @emitter.on 'set-option', (option) =>
      # Inform subsystems so they do their thing
      @mediaManager.systemEvent('set-option',option)


    @emitter.on 'md-detect', (player) =>
      # Inform subsystems so they do their thing
      if !@ready
        chiika.logger.warn("Media player detection has to wait until post initialization.")

        @emitter.on 'post-init-complete', =>
          @ipcManager.systemEvent('md-detect',player)
      else
        @ipcManager.systemEvent('md-detect',player)

    @emitter.on 'update-available', =>
      @ipcManager.systemEvent('squirrel','update-available')

    @emitter.on 'update-not-available', =>
      @ipcManager.systemEvent('squirrel','update-not-available')

    @emitter.on 'checking-for-update', =>
      @ipcManager.systemEvent('squirrel','checking-for-update')

    @emitter.on 'update-downloaded', =>
      @ipcManager.systemEvent('squirrel','update-downloaded')

    @emitter.on 'update-error', (error) =>
      @ipcManager.systemEvent('squirrel','update-error')

    #
    #
    #
    @emitter.on 'md-close', () =>
      # Inform subsystems so they do their thing
      @ipcManager.systemEvent('md-close')

    @emitter.on 'post-init-complete', () =>
      @ready = true

  getAppHome: ->
    @chiikaHome
  getDbHome: ->
    path.join(@chiikaHome,"data","database")
  getScriptCachePath: ->
    path.join(@chiikaHome,'cache','scripts')

  updaterWindow: (callback) ->
    options =
      width: 400
      height: 400
      backgroundColor: '#2e2c29'
      frame: false
      show: false
      icon: "resources/icon.png"
      title: 'Chiika'
      skipTaskbar: true
    installerWindow = new BrowserWindow options
    installerWindow.loadURL("file://#{__dirname}/../static/update-window.html")

    # if @devMode
    #   installerWindow.openDevTools({ detach: true })

    installerWindow.once 'ready-to-show',() =>
      installerWindow.show()
      callback?()

    return installerWindow




app = new Application()
