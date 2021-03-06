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
{Emitter}                                 = require 'event-kit'
{ipcRenderer,remote,shell}                = require 'electron'
remote                                    = require('electron').remote
{Menu,MenuItem,dialog}                    = require('electron').remote
animejs                                   = require 'animejs'

_when                                     = require 'when'
Logger                                    = require './main_process/logger'
_find                                     = require 'lodash/collection/find'
_indexOf                                  = require 'lodash/array/indexOf'
_forEach                                  = require 'lodash/collection/forEach'

ChiikaIPC                                 = require './chiika-ipc'
ViewManager                               = require './view-manager'
CardManager                               = require './card-manager'
NotificationManager                       = require './notification-manager'
SearchManager                             = require './search-manager'
ListManager                               = require './list-manager'

Toastr                                    = require 'toastr'

class ChiikaEnvironment
  emitter: null

  constructor: (params={}) ->
    {@applicationDelegate, @window,@chiikaHome} = params

    window.chiika = this

    isDevMode = process.env.DEV_MODE
    if !isDevMode?
      isDevMode = false
    @devMode = JSON.parse(isDevMode)


    @emitter          = new Emitter
    @logger           = remote.getGlobal('logger')

    @ipc                 = new ChiikaIPC()
    @viewManager         = new ViewManager()
    @cardManager         = new CardManager()
    @notificationManager = new NotificationManager()
    @searchManager       = new SearchManager()
    @listManager         = new ListManager()





    @ipc.onReconstructUI()
    @ipc.spectron()

    ipcRenderer.on 'squirrel', (event,args) =>
      console.log args

      if args == 'update-available'
        @emitter.emit 'update-available'

      if args == 'update-error'
        @emitter.emit 'update-not-available'


    ipcRenderer.on 'show-toast', (event,args) =>
      message = args.message
      duration = args.duration
      type = args.type

      if type == 'success'
        chiika.toastSuccess(message,duration)
      if type == 'error'
        chiika.toastError(message,duration)
      if type == 'loading'
        chiika.toastLoading(message,duration)
      if type == 'info'
        chiika.toastInfo(message,duration)

    ipcRenderer.on 'navigate-to', (event,args) =>
      url = args.route
      if url?
        window.location = url



  setTheme: (theme) ->
    if !@devMode
      if theme == 'Dark'
        $("link[rel='stylesheet']").attr('href','../styles/app_dark.css')
      else
        $("link[rel='stylesheet']").attr('href','../styles/app_light.css')
    else
      @notificationManager.error("Due to (arguably) technical limitations, we can't (allegedly) change theme when in DEV_MODE. Try this option on prod environment.")

  scanLibrary: (callback) ->
    chiika.toastLoading('Scanning library...',50000)
    chiika.ipc.sendMessage 'start-library-scan'
    chiika.ipc.receive 'scan-library-response', (event,result) =>
      @ipc.disposeListeners('scan-library-response')

      @closeLastToast()
      @notificationManager.scanResultsInfo(result.recognizedFiles,result.unRecognizedFiles,result.time)
      callback?()

  openFolderByEntry: (title) ->
    @scriptAction 'media','open-folder', { title: title }, (args) =>
      if args.state == 'not-found'
        @notificationManager.folderNotFound =>
          folders = dialog.showOpenDialog({
            properties: ['openDirectory']
          })

          if folders?
            chiika.scriptAction('media','set-folders-for-entry', { title: title,folder: folders })

  setFolderByEntry: (title) ->
    folders = dialog.showOpenDialog({
      properties: ['openDirectory']
    })

    if folders?
      chiika.scriptAction('media','set-folders-for-entry', { title: title,folder: folders })

  playEpisodeByNumber: (title,episode) ->
    chiika.scriptAction 'media','play-episode', { title: title,episode: episode }, (args) =>
      if args.state == 'episode-not-found'
        @notificationManager.episodeNotFound title,episode, () =>
          @setFolderByEntry(title)





  setUIViewConfig: (uiItem) ->
    chiika.ipc.sendMessage 'set-ui-config', { item: uiItem }

  #
  #
  #
  refreshViewByName: (view,owner) ->
    # Find UI Item if it has one, mark its state
    view = _find @viewData, (o) -> o.name == view

    if view?
      ui = _find @uiData, (o) -> o.name == view.name
      ui.state = 0
      @emitter.emit 'ui-data-refresh', { item: ui }

    @ipc.refreshViewByName(view.name,owner)

  requestViewDataUpdate: (owner,view) ->
    @ipc.sendMessage 'request-view-data-update', { owner: owner, viewName: view }

  openShellUrl: (url) ->
    shell.openExternal(url)

  toggleDevTools: ->
    isDevToolsOpen = remote.getCurrentWindow().isDevToolsOpened()
    if isDevToolsOpen
      @ipc.sendMessage 'call-window-method','closeDevTools'
    else
      @ipc.sendMessage 'call-window-method','openDevTools'

  checkForUpdates: ->
    @ipc.sendMessage 'check-for-updates'


  popupContextMenu: (config) ->
    menu = new Menu()
    _forEach config,(item) ->
      menu.append (new MenuItem item)
    menu.popup(remote.getCurrentWindow())

  notification: (notf) ->
    title = notf.title
    message = notf.message
    type = notf.type
    confirmText = notf.confirmText

    swalOptions =
      title: title
      text: message
      type: type
      html: if notf.html? then true else false

    if type == 'dialog'
      type = 'info'

      swalOptions.type = type
      swalOptions.showCancelButton = true
      swalOptions.confirmButtonColor = "#48c85e"
      swalOptions.confirmButtonText = confirmText
      swalOptions.closeOnConfirm = true
      window.swal(swalOptions,notf.confirm)
    else
      window.swal(swalOptions)

  toast: (toast) ->
    options =
      closeButton: false
      debug:false
      "newestOnTop": false
      "progressBar": if toast.progressBar? then true else false
      "positionClass": toast.position
      "preventDuplicates": false
      "onclick": null
      "showDuration": 300
      "hideDuration": 1000
      "timeOut": toast.duration
      "extendedTimeOut": 1000
      "showEasing": "swing"
      "hideEasing": "linear"
      "showMethod": "fadeIn"
      "hideMethod": "fadeOut"
    console.log "Toastr : Duration - #{toast.duration} - Position - #{toast.position}"
    @lastToast = Toastr[toast.theme](toast.message,'Chiika',options)

  closeToast: () ->
    Toastr.clear()

  closeLastToast: ->
    if @lastToast
      Toastr.clear(@lastToast)

  toastSuccess: (message,duration) ->
    @toast({
      message: message,
      duration: duration,
      theme: 'success',
      position: 'toast-bottom-right'
      })

  toastInfo: (message,duration) ->
    @toast({
      message: message,
      duration: duration,
      theme: 'info',
      position: 'toast-bottom-right'
      })

  toastError: (message,duration) ->
    @toast({
      message: message,
      duration: duration,
      theme: 'error',
      position: 'toast-bottom-right'
      })

  toastLoading: (message,duration) ->
    @toast({
      message: message,
      duration: duration,
      theme: 'info',
      position: 'toast-bottom-right',
      progressBar: true
      })

  getOption: (option) ->
    @appSettings[option]

  setOption: (option,value) ->
    @appSettings[option] = value
    @ipc.setOption(option,value)

    @viewManager.optionChanged(option,value)

  getDefaultService: ->
    defaultUser = _find @users,(o) -> o.isDefault == true
    if defaultUser?
      defaultUser.owner

  mediaAction: (owner,action,params,callback) ->
    @ipc.sendMessage 'media-action', { owner:owner, action:action, params: params }

    ipcRenderer.on "media-action-#{action}-response", (event,args) =>
      callback(args)
      @ipc.disposeListeners("media-action-#{action}-response")

  #
  #
  #
  scriptAction: (owner,action,params,callback) ->
    if !params?
      params = {}

    @ipc.sendMessage 'script-action', { owner: owner, action: action, params: params, return: callback }
    @ipc.receive "script-action-#{action}-response", (event,args) =>
      callback?(args)

      @ipc.disposeListeners("script-action-#{action}-response")

  sendNotification: (title,body,icon) ->
    if !icon?
      icon = __dirname + "/../assets/images/chiika.png"
    notf = new Notification(title,{ body: body, icon: icon})

  reInitializeUI: (delay) ->
    console.log "Reinitiazing UI"

    if !delay?
      delay = 500
    @emitter.emit 'reinitialize-ui',{ delay: delay }

  domReady: ->
    @searchManager.postInit()


  preload: ->
    waitForUI = _when.defer()
    waitForViewData = _when.defer()
    waitForSettingsData = _when.defer()
    waitForPostInit = _when.defer()
    waitForViewByName = _when.defer()
    waitForUIDataByName = _when.defer()

    async = [ waitForUI.promise, waitForViewData.promise,waitForSettingsData.promise,waitForPostInit.promise ]

    ipcRenderer.on 'get-view-data-by-name-response', (event,args) =>
      @logger.renderer("get-view-data-by-name-response - #{args.name}")
      name = args.name

      waitForViewByName.resolve()

      findView = _find @viewData, (o) -> o.name == name
      index    = _indexOf @viewData, findView
      if findView?
        if args.view?
          @viewData.splice(index,1,args.view)
          @logger.renderer("ViewData - Replacing #{name}")
        else
          @viewData.splice(index,1)
          @logger.renderer("ViewData - Removing #{name}")
      else
        @logger.renderer("Could not find view in renderer #{name}. Current views: ")
        @viewData.push args.view


      @emitter.emit 'view-refresh', { view: name }

      # Check UI item
      findUiItem = _find @uiData, (o) -> o.name == name
      index    = _indexOf @uiData, findUiItem

      if index > -1
        findUiItem.state = 1
        @emitter.emit 'ui-data-refresh', { item: args.item }




    ##########################


    ipcRenderer.on 'get-ui-data-by-name-response', (event,args) =>
      @logger.renderer("get-ui-data-by-name-response - #{args.name}")
      name = args.name

      waitForUIDataByName.resolve()

      findUiItem = _find @uiData, (o) -> o.name == name
      index    = _indexOf @uiData, findUiItem
      if findUiItem?
        if args.item?
          @uiData.splice(index,1,args.item)
          @logger.renderer("UIDATA - Replacing #{name}")
        else
          @uiData.splice(index,1)
          @logger.renderer("UIDATA - Removing #{name}")
      else
        @uiData.push args.item

      @uiData.sort (a,b) =>
        if a.type.indexOf('card') == -1
          return 0
        else
          if b? && a?
            if b.cardProperties.order > a.cardProperties.order
              return -1
            else
              return 1
          else
            return 0
        return 0

      @emitter.emit 'ui-data-refresh', { item: args.item }



    ##########################

    @ipc.sendMessage 'get-ui-data'
    @ipc.refreshUIData (args) =>
      @uiData = args
      chiika.logger.renderer("UI data is present.")

      @uiData.sort (a,b) =>
        if a.type.indexOf('card') == -1
          return 0
        else
          if b? && a?
            if b.cardProperties.order > a.cardProperties.order
              return -1
            else
              return 1
          else
            return 0
        return 0

      infoStr = ''
      for uiData in @uiData
        infoStr += " #{uiData.display} ( #{uiData.type} )"

      chiika.logger.renderer("Current UI items are #{infoStr}")
      waitForUI.resolve()

    @ipc.sendMessage 'get-view-data'
    @ipc.getViewData (args) =>
      @viewData = args

      waitForViewData.resolve()

    @ipc.sendMessage 'get-settings-data'
    @ipc.getSettings (args) =>
      @appSettings = args

      waitForSettingsData.resolve()

    @ipc.sendMessage 'get-user-data'
    @ipc.receive 'get-user-data-response', (event,args) =>
      @users = args

    @ipc.sendMessage 'get-services'
    @ipc.receive 'get-services-response', (event,args) =>
      @services = args

    @ipc.sendMessage 'post-init'
    ipcRenderer.on 'post-init-response', (event,args) =>
      waitForPostInit.resolve()
    _when.all(async)

  onReinitializeUI: (loading,main) ->
    @emitter.on 'reinitialize-ui', (args) =>
      loading()

      @ipc.disposeListeners('get-ui-data-response')

      @preload().then =>
        setTimeout(main,args.delay)
module.exports = ChiikaEnvironment
