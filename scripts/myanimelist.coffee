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

path          = require 'path'
fs            = require 'fs'


getLibraryUrl = (type,user) ->
  return "http://myanimelist.net/malappinfo.php?u=#{user}&type=#{type}&status=all"


authUrl                       = 'http://myanimelist.net/api/account/verify_credentials.xml'
animePageUrl                  = 'http://myanimelist.net/anime/'
mangaPageUrl                  = 'http://myanimelist.net/manga/'
updateAnime                   = 'http://myanimelist.net/api/animelist/update/'
updateManga                   = 'http://myanimelist.net/api/mangalist/update/'
addAnime                      = 'http://myanimelist.net/api/animelist/add/'

getSearchUrl = (type,keywords) ->
  "http://myanimelist.net/api/#{type}/search.xml?q=#{keywords}"

getSearchExtendedUrl = (type,id) ->
  if type == 'manga'
    "http://myanimelist.net/includes/ajax.inc.php?id=#{id}&t=65"
  else
    "http://myanimelist.net/includes/ajax.inc.php?id=#{id}&t=64"

_assign       = scriptRequire 'lodash.assign'
_find         = scriptRequire 'lodash/collection/find'
_isArray      = scriptRequire 'lodash.isarray'
_forEach      = scriptRequire 'lodash.forEach'
_cloneDeep    = scriptRequire 'lodash.cloneDeep'
_size         = scriptRequire 'lodash/collection/size'

_when         = scriptRequire 'when'
string        = scriptRequire 'string'
xml2js        = scriptRequire 'xml2js'
moment        = scriptRequire 'moment'
{shell}       = require 'electron'


module.exports = class MyAnimelist
  # Description for this script
  # Will be visible on app
  displayDescription: "MyAnimelist"

  # Unique identifier for the app
  #
  name: "myanimelist"

  # Logo which will be seen at the login screen
  #
  logo: '../assets/images/login/mal1.png'

  # Chiika lets you define multiple users
  # In the methods below you can use whatever user you want
  # For the default we use the user when you login.
  #
  malUser: null

  #
  #
  #
  isService: true

  #
  #
  #
  isActive: true

  order: 0

  #
  # The time limit between Chiika should scrape the entry's MAL page
  #
  detailsSyncTimeRestriction:9

  # Will be called by Chiika with the API object
  # you can do whatever you want with this object
  # See the documentation for this object's methods,properties etc.
  constructor: (chiika) ->
    @chiika = chiika

  # This method is controls the communication between app and script
  # If you change this method things will break
  #
  on: (event,args...) ->
    @chiika.on @name,event,args...


  # myanimelist.net/malappinfo.php?u=#user&type=anime&status=all
  # Retrieves library
  # @param type {String} anime-manga
  retrieveLibrary: (type,userName,callback) ->
    userName = string(userName).chompRight("_" + @name).s
    @chiika.logger.info("Retrieving user library for #{userName} - #{type}")
    onGetUserLibrary = (error,response,body) =>

      if response.statusCode == 200 or response.statusCode == 201
        @chiika.parser.parseXml(body)
                      .then (result) =>
                        callback { success:true,response: response, library: result }
      else
        @chiika.logger.warn("There was a problem retrieving library.")
        callback { success:false,response: response }

    @chiika.makeGetRequest getLibraryUrl(type,userName),null, onGetUserLibrary

  #
  #
  #
  getAnimelistData: (callback) ->
    if !@malUser?
      @chiika.logger.error("User can't be retrieved.Aborting anime list request.")
      callback( {success: false })
    else
      @retrieveLibrary 'anime',@malUser.realUserName, (result) =>
           userInfo = result.library.myanimelist.myinfo

           _assign @malUser, { malAnimeInfo: userInfo }
           @chiika.users.updateUser @malUser

           callback(result)

  #
  #
  #
  getMangalistData: (callback) ->
    if @malUser?
      @retrieveLibrary 'manga',@malUser.realUserName, (result) =>
           userInfo = result.library.myanimelist.myinfo

           _assign @malUser, { malMangaInfo: userInfo }
           @chiika.users.updateUser @malUser

           callback(result)

    else
      @chiika.logger.error("User can't be retrieved.Aborting manga list request.")
      callback( { success: false })


  authorizedPost: (url,body,callback) ->
    onAuthorizedPostComplete = (error,response,body) =>
      if error
        callback( { success: false , response: body, statusCode: response.statusCode })

      else if response.statusCode != 200
        callback( { success: false , response: body, statusCode: response.statusCode })

      else
        callback( { success: true, response: body, statusCode: response.statusCode })

    @chiika.makePostRequestAuth( url, { userName: @malUser.realUserName, password: @malUser.password },null,body, onAuthorizedPostComplete )

  #
  #
  #
  updateAnime: (anime,callback) ->
    anime.animeLastUpdated = moment().unix()
    data = @buildAnimeXmlForUpdating(anime)
    @authorizedPost "#{updateAnime}#{anime.mal_id}.xml",data,(result) =>
      if result.success && result.response == "Updated"
        callback(result)

        #Save history
        historyView = @chiika.viewManager.getViewByName('myanimelist_animelist_history')

        if historyView?
          historyData = historyView.getData()

          historyItem =
            history_id: historyData.length
            updated: moment().valueOf()
            id: anime.mal_id
            episode: anime.animeWatchedEpisodes

          historyView.setData( historyItem, 'history_id').then (args) =>
            @chiika.requestViewDataUpdate('cards','cards_statistics')
            @chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')
            @chiika.requestViewDataUpdate('cards','cards_continueWatching')
      else
        # It can return status code 200 but if the body isn't updated,it failed.
        result.success = false
        callback(result)

  #
  #
  #
  addAnime: (anime,callback) ->
    data = @buildAnimeXmlForUpdating(anime)
    @authorizedPost "#{addAnime}#{anime.mal_id}.xml",data,(result) =>
      if result.statusCode == 201
        callback?(result)
      else
        callback?(result)

        # Problems

  #
  #
  #
  updateManga: (manga,callback) ->
    manga.mangaLastUpdated = moment().unix()
    data = @buildMangaXmlForUpdating(manga)
    @authorizedPost "#{updateManga}#{manga.mal_id}.xml",data,(result) =>
      if result.success && result.response == "Updated"
        callback(result)

        # Statistics update on history method
        @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')
      else
        # It can return status code 200 but if the body isn't updated,it failed.
        result.success = false
        callback(result)

  #
  # Searches animelist either manga or anime
  #
  search: (type,keywords,callback) ->
    if @malUser?
      onSearchComplete = (error,response,body) =>
        @chiika.parser.parseXml(body)
                      .then (result) =>
                        if type == 'anime'
                          callback(result.anime.entry)
                        else if type == 'manga'
                          callback(result.manga.entry)
    else
      @chiika.logger.error("User can't be retrieved.Aborting search request.")
      callback( { success: false })


     @chiika.makeGetRequestAuth getSearchUrl(type,keywords.split(" ").join("+")),{ userName: @malUser.realUserName, password: @malUser.password },null, onSearchComplete



  #
  #
  #
  searchExtended: (type,id,callback) ->
    onSearchComplete = (error,response,body) =>
      if type == 'anime'
        callback(@chiika.parser.parseMyAnimelistExtendedSearch(body))
      else if type == 'manga'
        callback(@chiika.parser.parseMyAnimelistMangaExtendedSearch(body))

    @chiika.makeGetRequest getSearchExtendedUrl(type,id),null, onSearchComplete


  animePageScrape: (id,callback) ->
    onRequest = (error,response,body) =>
      callback(@chiika.parser.parseAnimeDetailsMalPage(body))

    @chiika.makeGetRequest animePageUrl + id,null,onRequest


  mangaPageScrape: (id,callback) ->
    onRequest = (error,response,body) =>
      callback(@chiika.parser.parseMangaDetailsMalPage(body))

    @chiika.makeGetRequest mangaPageUrl + id,null,onRequest


  # After the constructor run() method will be called immediately after.
  # Use this method to do what you will
  #
  run: () ->
    @on 'initialize', =>
      @malUser = @chiika.users.getDefaultUser(@name)

      if @malUser?
        @chiika.logger.info("Default user : #{@malUser.realUserName}")
      else
        @chiika.logger.warn("Default user for myanimelist doesn't exist. If this is the first time launch, you can ignore this.")

      animelistView   = @chiika.viewManager.getViewByName('myanimelist_animelist')
      animeExtraView  = @chiika.viewManager.getViewByName('myanimelist_animeextra')

      mangalistView = @chiika.viewManager.getViewByName('myanimelist_mangalist')
      mangaExtraView  = @chiika.viewManager.getViewByName('myanimelist_mangaextra')

      if animelistView?
        @animelist = animelistView.getData()
        @chiika.logger.script("[yellow](#{@name}) Animelist data length #{@animelist.length} #{@name}")

      if mangalistView?
        @mangalist = mangalistView.getData()
        @chiika.logger.script("[yellow](#{@name}) Mangalist data length #{@mangalist.length} #{@name}")


      if animeExtraView?
        @animeextra = animeExtraView.getData()
        @chiika.logger.script("[yellow](#{@name}) AnimeExtra data length #{@animeextra.length} #{@name}")

      if mangaExtraView?
        @mangaextra = mangaExtraView.getData()
        @chiika.logger.script("[yellow](#{@name}) MangaExtra data length #{@mangaextra.length} #{@name}")

    @on 'post-init',(init) =>
      init.defer.resolve()

    # This method will be called if there are no UI elements in the database
    # or the user wants to refresh the views
    @on 'reconstruct-ui', (update) =>
      @chiika.logger.script("[yellow](#{@name}) reconstruct-ui #{@name}")

      @createViewAnimelist()
      @createViewMangalist()
      @createViewAnimeExtra()
      @createViewMangaExtra()

    # This event is called each time the associated view needs to be updated then saved to DB
    # Note that its the actual data refreshing. Meaning for example, you need to SYNC your data to the remote one, this event occurs
    # This event won't be called each application launch unless "RefreshUponLaunch" option is ticked
    # You should update your data here
    # This event will then save the data to the view's local DB to use it locally.
    @on 'view-update', (update) =>
      @chiika.logger.script("[yellow](#{@name}) Updating view for #{update.view.name} - #{@name}")

      if update.view.name == 'myanimelist_animelist'
        #view.setData(@getAnimelistData())
        @getAnimelistData (result) =>
          if result.success
            @setAnimelistTabViewData(result.library.myanimelist.anime,update.view).then =>
              update.return({ success: result.success })

              # Save the date of this process
              @chiika.custom.addKey { name: "#{update.view.name}_updated", value:moment() }
          else
            @chiika.logger.warn("[yellow](#{@name}) view-update has failed.")
            update.return({ success: result.success })


      else if update.view.name == 'myanimelist_mangalist'
        @getMangalistData (result) =>
          if result.success
            @setMangalistTabViewData(result.library.myanimelist.manga,update.view).then =>
              update.return({ success: result.success })

              @chiika.custom.addKey { name: "#{update.view.name}_updated", value:moment() }
          else
            update.return({ success: result.success })


    @on 'details-layout', (args) =>
      @chiika.logger.script("[yellow](#{@name}) Details-Layout #{args.id}")

      id        = args.id
      viewName  = args.viewName

      if viewName == 'myanimelist_animelist'
        @onAnimeDetailsLayout(id,args.return)

      if viewName == 'myanimelist_mangalist'
        animeEntry = _find @mangalist, (o) -> (o.mal_id) == args.id
        extraEntry = _find @mangaextra, (o) -> (o.mal_id) == args.id

        timeSinceLastUpdate = @detailsSyncTimeRestriction
        if extraEntry?
          lastSync = extraEntry.lastSync
          now = moment()
          diff = moment.duration(now.diff(lastSync)).asHours()
          timeSinceLastUpdate = diff
        if timeSinceLastUpdate < @detailsSyncTimeRestriction - 1
          @chiika.logger.script("#{args.id} was last updated #{timeSinceLastUpdate} hours ago.There is no need to update")
        else
          @handleMangaDetailsRequest id, (response) =>
            mangaExtraView = @chiika.viewManager.getViewByName('myanimelist_mangaextra')
            @mangaextra = mangaExtraView.getData()

            if response.success && response.updated > 0
              args.return({ updated: false, layout: @getMangaDetailsLayout(id)})

              @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')


        args.return({ updated: false, layout: @getMangaDetailsLayout(id)})

    @on 'details-action', (args) =>
      action = args.action
      layout = args.layout
      params = args.params

      @chiika.logger.script("Receiving details-action - #{action} for #{@name}")

      onActionError = (error) =>
        @chiika.logger.script("Could not perform action #{action}")
        if error?
          @chiika.logger.script(error)

        args.return({ success: false, error: error })

      switch action
        when 'progress-update'
          item = params.item
          if params.viewName == 'myanimelist_animelist'
            @updateProgress layout.id,'anime',item.current, (result) =>
              args.return(result)

          if params.viewName == 'myanimelist_mangalist'
            newProgress = { }
            if item.title == 'Chapters'
              newProgress = { chapters: item.current, volumes: layout.status.items[1].current,type: item.title }
            if item.title == 'Volumes'
              newProgress = { volumes: item.current, chapters: layout.status.items[0].current,type: item.title }

            @updateProgress layout.id,'manga',newProgress, (result) =>
              args.return(result)

        when 'score-update'
          item = params.item
          if params.viewName == 'myanimelist_animelist'
            @updateScore layout.id,'anime',item.current, (result) =>
              args.return(result)

          if params.viewName == 'myanimelist_mangalist'
            @updateScore layout.id,'manga',item.current, (result) =>
              args.return(result)

        when 'status-update'
          item = params.item

          if params.viewName == 'myanimelist_animelist'
            @updateStatus layout.id,'anime',item.identifier, (result) =>
              args.return(result)

          if params.viewName == 'myanimelist_mangalist'
            @updateStatus layout.id,'manga',item.identifier, (result) =>
              args.return(result)

        when 'cover-click'
          id = layout.id
          if id?
            if params.viewName == 'myanimelist_animelist'
              result = shell.openExternal("http://myanimelist.net/anime/#{id}")
            else
              result = shell.openExternal("http://myanimelist.net/manga/#{id}")
            args.return({ success:result })
          else
            @onActionError("Need ID for cover-click")

        when 'character-click'
          if !params.id?
            onActionError("Need ID for character-click")
          else
            result = shell.openExternal("http://myanimelist.net/character/#{params.id}")
            args.return({ success:result })



    @on 'get-view-data', (args,callback) =>
      view = args.view
      data = args.data

      @chiika.logger.script("[yellow](#{@name}) Requesting View Data for #{view.name}")

      if view.name == 'myanimelist_animelist'
        watching    = []
        ptw         = []
        onhold      = []
        dropped     = []
        completed   = []

        _forEach data, (anime) =>
          status = anime.animeUserStatus

          animeValues = @getAnimeValues(anime)

          newAnime = _cloneDeep anime

          # Pre process - add some more columns
          newAnime.animeProgress                 = (parseInt(anime.animeWatchedEpisodes) / parseInt(anime.animeTotalEpisodes)) * 100
          newAnime.animeScoreAverage             = animeValues.averageScore
          newAnime.animeTypeText                 = animeValues.typeText
          newAnime.animeSeason                   = animeValues.season
          newAnime.animeLastUpdatedText          = animeValues.lastUpdatedText


          if status == "1"
            watching.push newAnime
          else if status == "2"
            completed.push newAnime
          else if status == "3"
            onhold.push newAnime
          else if status == "4"
            dropped.push newAnime
          else if status == "6"
            ptw.push newAnime

        animelistData = []

        animelistData.push { name: 'al_watching',data: watching }
        animelistData.push { name: 'al_ptw',data: ptw }
        animelistData.push { name: 'al_dropped',data: dropped }
        animelistData.push { name: 'al_onhold',data: onhold }
        animelistData.push { name: 'al_completed',data: completed }
        args.return(animelistData)


      else if view.name == 'myanimelist_mangalist'
        reading     = []
        ptr         = []
        onhold      = []
        dropped     = []
        completed   = []

        _forEach data, (manga) =>
          status = manga.mangaUserStatus

          mangaValues = @getMangaValues(manga)

          newManga = _cloneDeep manga

          # Pre process - add some more columns
          newManga.mangaProgress                 = "#{manga.mangaUserReadChapters} / #{manga.mangaUserReadVolumes}"
          newManga.mangaScoreAverage             = mangaValues.averageScore
          newManga.mangaLastUpdatedText          = mangaValues.lastUpdatedText


          if status == "1"
            reading.push newManga
          else if status == "2"
            completed.push newManga
          else if status == "3"
            onhold.push newManga
          else if status == "4"
            dropped.push newManga
          else if status == "6"
            ptr.push newManga

        mangalistData = []

        mangalistData.push { name: 'ml_reading',data: reading }
        mangalistData.push { name: 'ml_ptr',data: ptr }
        mangalistData.push { name: 'ml_dropped',data: dropped }
        mangalistData.push { name: 'ml_onhold',data: onhold }
        mangalistData.push { name: 'ml_completed',data: completed }
        args.return(mangalistData)

      else if args.view.name == 'myanimelist_animelist_history'
        animelistView = @chiika.viewManager.getViewByName('myanimelist_animelist')

        historyView = @chiika.viewManager.getViewByName('myanimelist_animelist_history')

        if historyView?
          historyData = historyView.getData()

          currentMonth = moment().month()
          currentYear  = moment().year()
          sixWeeksAgo  = moment().subtract(6,'weeks')

          monthNumbers = [0,0,0,0,0,0,0,0,0,0,0,0]
          sixWeeks = [0,0,0,0,0,0]
          watchedByMonth = monthNumbers


          _forEach historyData, (history) ->
            lastUpdated = history.updated

            date = moment(lastUpdated)

            if date.isValid() && date.year() == currentYear
              month = date.month()
              watchedByMonth[month] += 1

            if date.isValid() && date.isAfter(sixWeeksAgo)
              howManyWeeks = (moment.duration(date.diff(sixWeeksAgo)).asWeeks())

              if howManyWeeks < 6
                round = Math.round(howManyWeeks)
                sixWeeks[6 - round] += 1

            #else
              #console.log date.format("YYYY/MM/DD HH:mm") + " was not at least six weeks ago!"

            if !date.isValid()
              console.log "WARNING #{history.id} DATE IS NOT VALID!!"


          nonZeroDataPoints = 0
          chartLabels = []
          dataPoints  = []
          for i in [0...watchedByMonth.length+1]
            if watchedByMonth[i] != 0
              nonZeroDataPoints++

          if nonZeroDataPoints > 3
            for i in [0...watchedByMonth.length]
              if watchedByMonth[i] != 0
                chartLabels.push moment.months()[i]
                dataPoints.push watchedByMonth[i]
          else
            # Show last 6 weeks?
            for i in [5...-1]
              if i == 0
                chartLabels.push "This Week"
              else if i == 5
                chartLabels.push moment.months()[moment().month() - 1 ]
              else if i == 2
                chartLabels.push moment.months()[moment().month() ]
              else
                chartLabels.push ""
              dataPoints.push sixWeeks[i]

          chartEpisodesWatched =
            labels: chartLabels
            mode: nonZeroDataPoints
            datasets: [
              { name: 'Episodes Watched since 6 weeks',
              labels: chartLabels,
              data: dataPoints,
              backgroundColor: 'rgba(75,192,192,0.4)',
              borderColor: 'rgba(75,192,192,1)',
              pointBorderColor: 'rgba(75,192,192,1)',
              pointHoverBackgroundColor: 'rgba(75,192,192,1)',
              pointHoverBorderColor: 'rgba(220,220,220,1)'}
            ]
          args.return([chartEpisodesWatched])

    # This function is called from the login window.
    # For example, if you need a token, retrieve it here then store it by calling chiika.custom.addkey
    # Note that you dont have to do anything here if you want
    # But storing a user to avoid logging in each time you launch the app is a good practice
    # Another note is , you MUST call the  'args.return' or the app wont continue executing
    #
    @on 'set-user-login', (args,callback) =>
      @chiika.logger.script("[yellow](#{@name}) Auth in process " + args.user)

      onAuthComplete = (error,response,body) =>
        if error?
          @chiika.logger.error(error)
        else
          if response.statusCode == 200 or response.statusCode == 201
            userAdded = =>
              async = []

              deferUpdate1 = _when.defer()
              deferUpdate2 = _when.defer()
              deferUpdate3 = _when.defer()
              deferUpdate4 = _when.defer()
              async.push deferUpdate1.promise
              async.push deferUpdate2.promise
              async.push deferUpdate3.promise
              async.push deferUpdate4.promise

              @chiika.requestViewUpdate 'myanimelist_animelist',@name,() => deferUpdate1.resolve()
              @chiika.requestViewUpdate('myanimelist_mangalist',@name,() => deferUpdate2.resolve())

              @importHistoryFromMAL('anime', () => deferUpdate3.resolve() )
              @importHistoryFromMAL('manga', () => deferUpdate4.resolve() )

              _when.all(async).then =>
                args.return( { success: true })

            newUser = { userName: args.user + "_" + @name,owner: @name, password: args.pass, realUserName: args.user }

            @chiika.parser.parseXml(body)
                         .then (xmlObject) =>
                           @malUser = @chiika.users.getUser(args.user + "_" + @name)

                           _assign newUser, { malID: xmlObject.user.id }
                           if @malUser?
                             _assign @malUser,newUser
                             @chiika.users.updateUser @malUser,userAdded
                           else
                             @malUser = newUser
                             @chiika.users.addUser @malUser,userAdded

            #  if chiika.users.getUser(malUser.userName)?
            #    chiika.users.updateUser malUser
            #  else
            #  chiika.users.addUser malUser
          else
            #Login failed, use the callback to tell the app that login isn't succesful.
            #
            args.return( { success: false, response: response })

      @chiika.makePostRequestAuth( authUrl, { userName: args.user, password: args.pass },null,null, onAuthComplete )


    @on 'system-event', (event) =>
      if event.name == 'shortcut-pressed'
        if event.params.action == 'test3'
          @chiika.emit 'scan-library', { calling: 'media' }



    @on 'get-anime-values', (args) =>
      args.return @getAnimeValues(args.entry)

    @on 'make-search', (args) =>
      @chiika.logger.script("[yellow](#{@name}) make-search #{args.title}")

      title = args.title
      @doSearch title, (results) =>
        args.return(results)

    @on 'add-anime', (args) =>
      entry = args.entry
      status = args.status

      entry.animeWatchedEpisodes = "0"
      entry.animeUserStatus = status
      entry.animeScore = "0"

      @addAnime entry, (result) =>
        if result.statusCode == 201
          args.return()
          # @updateViewAndRefresh 'myanimelist_animelist',entry,'mal_id', (result) =>
          #   @chiika.showToast("#{entry.animeTitle} has been added succesfully!",3000,'success')
          #
          #   @chiika.requestViewDataUpdate(@name,'myanimelist_animelist')
          #
          #   args.return()


  saveMangaHistory: (type,manga) ->
    #Save history
    historyView = @chiika.viewManager.getViewByName('myanimelist_mangalist_history')

    if historyView?
      historyData = historyView.getData()
      historyItem = {}

      if type == 'chapters'
        historyItem =
          history_id: historyData.length
          updated: moment().valueOf()
          id: manga.mal_id
          chapters: manga.mangaUserReadChapters

      if type == 'volumes'
        historyItem =
          history_id: historyData.length
          updated: moment().valueOf()
          id: manga.mal_id
          volumes: manga.mangaUserReadVolumes

      historyView.setData( historyItem, 'updated').then (args) =>
        @chiika.requestViewDataUpdate('cards','cards_statistics')

  onAnimeDetailsLayout: (id,callback) ->
    #If its on the list, it will have this entry
    animeEntry = _find @animelist, (o) -> (o.mal_id) == id
    extraEntry = _find @animeextra, (o) -> (o.mal_id) == id

    timeSinceLastUpdate = @detailsSyncTimeRestriction
    if extraEntry?
      lastSync = extraEntry.lastSync
      now = moment()
      diff = moment.duration(now.diff(lastSync)).asHours()
      timeSinceLastUpdate = diff


    if timeSinceLastUpdate < @detailsSyncTimeRestriction - 1
      @chiika.logger.script("#{id} was last updated #{timeSinceLastUpdate} hours ago.There is no need to update")
      callback({ updated: false, layout: @getAnimeDetailsLayout(id)})
    else
      @handleAnimeDetailsRequest id, (response) =>
        animeExtraView = @chiika.viewManager.getViewByName('myanimelist_animeextra')
        @animeextra = animeExtraView.getData()

        if response.success && response.updated > 0
          callback({ updated: true, layout: @getAnimeDetailsLayout(id)})

          @chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')
    callback({ updated: false, layout: @getAnimeDetailsLayout(id)})


  doSearch: (title,callback) ->
    searchMatch = (v) ->
      newAnimeEntry = {}
      newAnimeEntry.mal_id = v.id
      newAnimeEntry.animeEnglish = v.english
      newAnimeEntry.animeTitle = v.title
      newAnimeEntry.animeSynonyms = v.synonyms
      newAnimeEntry.animeType = v.type
      newAnimeEntry.animeStartDate = v.start_date
      newAnimeEntry.animeEndDate = v.end_date
      newAnimeEntry.animeStatus = v.status
      newAnimeEntry.animeImage = v.image
      newAnimeEntry.animeScoreAverage = v.score
      newAnimeEntry.animeSynopsis = v.synopsis
      newAnimeEntry

    results = []

    @search 'anime',title, (list) =>
      if _isArray list
        _forEach list, (entry) =>
          results.push searchMatch(entry)

      else
        results.push searchMatch(list)
        entryFound = true

      callback?(results)

  handleAnimeDetailsRequest: (animeId,callback) ->
    @chiika.logger.script("[yellow](#{@name}-Anime-Search) Searching for #{animeId}!")

    animeExtraView = @chiika.viewManager.getViewByName('myanimelist_animeextra')

    animeEntry = _find @animelist, (o) -> (o.mal_id) == animeId

    #Searching
    #
    # For search to occur, we need a title
    #
    searchMatch = (v) ->
      newAnimeEntry = {}
      newAnimeEntry.mal_id = v.id
      newAnimeEntry.animeEnglish = v.english
      newAnimeEntry.animeTitle = v.title
      newAnimeEntry.animeSynonyms = v.synonyms
      newAnimeEntry.animeType = v.type
      newAnimeEntry.animeStartDate = v.start_date
      newAnimeEntry.animeEndDate = v.end_date
      newAnimeEntry.animeStatus = v.status
      newAnimeEntry.animeImage = v.image
      newAnimeEntry.animeScoreAverage = v.score
      newAnimeEntry.animeSynopsis = v.synopsis
      newAnimeEntry

    newAnimeEntry = {}
    entryFound = false

    if animeEntry?
      #
      #
      # Mal API Search
      #
      #
      @search 'anime',animeEntry.animeTitle, (list) =>
        isArray = false
        if _isArray list
          isArray = true
          _forEach list, (v,k) =>
            if v.id == animeEntry.mal_id
              newAnimeEntry = searchMatch(v)
              entryFound = true
              return false
        else
          if list.id == animeEntry.mal_id
            newAnimeEntry = searchMatch(list)
            entryFound = true


        if isArray && list.length > 0 && entryFound
          newAnimeEntry.lastSync = moment().valueOf()
          @chiika.logger.script("[yellow](#{@name}-Anime-Search) Search returned #{list.length} entries")
          animeExtraView.setData(newAnimeEntry,'mal_id').then (args) =>
            if args.rows > 0
              @chiika.logger.script("[yellow](#{@name}-Anime-Search) Updated #{args.rows} entries.")
              animeExtraView.reload().then =>
                callback?({ success: true, entry: newAnimeEntry, updated: args.rows })
        else if _size(list) > 0 && entryFound
          newAnimeEntry.lastSync = moment().valueOf()
          @chiika.logger.script("[yellow](#{@name}-Anime-Search) Search returned 1 entry")
          animeExtraView.setData(newAnimeEntry,'mal_id').then (args) =>
            if args.rows > 0
              @chiika.logger.script("[yellow](#{@name}-Anime-Search) Updated #{args.rows} entries.")
              animeExtraView.reload().then =>
                callback?({ success: true, entry: newAnimeEntry, updated: args.rows })
        else if !entryFound
          callback({ success: false, response: "Search failed.",updated: 0 })


      #
      # http://myanimelist.net/includes/ajax.inc.php?id=id&t=64
      #
      @searchExtended 'anime', animeEntry.mal_id, (result) ->

        if result?
          newAnimeEntry = {}
          newAnimeEntry.mal_id = animeEntry.mal_id
          newAnimeEntry.animeGenres = result.genres
          newAnimeEntry.animeScoreAverage = result.score
          newAnimeEntry.animeRanked = result.rank
          newAnimeEntry.animePopularity = result.popularity
          newAnimeEntry.scoredBy = result.scoredBy

          animeExtraView.setData(newAnimeEntry,'mal_id').then (args) =>
            newAnimeEntry.lastSync = moment().valueOf()
            @chiika.logger.script("[yellow](#{@name}-Anime-Search-Extended) Updated #{args.rows} entries.")
            animeExtraView.reload().then =>
              callback?({ success: true, entry: newAnimeEntry, updated: args.rows, updated: 0 })
        else
          callback?({ success: false, response: "No Entry" })

      #
      # Anime Page Scraping
      #
      @animePageScrape animeEntry.mal_id, (result) ->

        if result?
          newAnimeEntry = {}
          newAnimeEntry.mal_id = animeEntry.mal_id
          newAnimeEntry.animeStudio = result.studio
          newAnimeEntry.animeSource = result.source
          newAnimeEntry.animeJapanese = result.japanese
          newAnimeEntry.animeBroadcast = result.broadcast
          newAnimeEntry.animeDuration = result.duration
          newAnimeEntry.animeAired = result.aired
          newAnimeEntry.animeCharacters = result.characters
          animeExtraView.setData(newAnimeEntry,'mal_id').then (args) =>
            newAnimeEntry.lastSync = moment().valueOf()
            @chiika.logger.script("[yellow](#{@name}-Anime-Mal-Scrape) Updated #{args.rows} entries.")
            animeExtraView.reload().then =>
              callback?({ success: true, entry: newAnimeEntry, updated: args.rows })
        else
          callback?({ success: false, response: "No Entry", updated: 0 })


  handleMangaDetailsRequest: (mangaId,callback) ->
    @chiika.logger.script("[yellow](#{@name}-Manga-Search) Searching for #{mangaId}!")

    mangaExtraView = @chiika.viewManager.getViewByName('myanimelist_mangaextra')

    mangaEntry = _find @mangalist, (o) -> (o.mal_id) == mangaId

    #Searching
    #
    # For search to occur, we need a title
    #
    searchMatch = (v) ->
      newMangaEntry = {}
      newMangaEntry.mal_id = v.id
      newMangaEntry.mangaEnglish = v.english
      newMangaEntry.mangaTitle = v.title
      newMangaEntry.mangaSynonyms = v.synonyms
      newMangaEntry.mangaType = v.type
      newMangaEntry.mangaStartDate = v.start_date
      newMangaEntry.mangaEndDate = v.end_date
      newMangaEntry.mangaImage = v.image
      newMangaEntry.mangaScoreAverage = v.score
      newMangaEntry.mangaSynopsis = v.synopsis
      newMangaEntry

    newMangaEntry = {}
    entryFound = false

    if mangaEntry?
      #
      #
      # Mal API Search
      #
      #
      @search 'manga',mangaEntry.mangaTitle, (list) =>
        isArray = false
        if _isArray list
          isArray = true
          _forEach list, (v,k) =>
            if v.id == mangaEntry.mal_id
              newMangaEntry = searchMatch(v)
              entryFound = true
              return false
        else
          if list.id == mangaEntry.mal_id
            newMangaEntry = searchMatch(list)
            entryFound = true


        if isArray && list.length > 0 && entryFound
          @chiika.logger.script("[yellow](#{@name}-Manga-Search) Search returned #{list.length} entries")
          mangaExtraView.setData(newMangaEntry,'mal_id').then (args) =>
            if args.rows > 0
              @chiika.logger.script("[yellow](#{@name}-Manga-Search) Updated #{args.rows} entries.")
              mangaExtraView.reload().then =>
                callback?({ success: true, entry: newMangaEntry, updated: args.rows })
        else if _size(list) > 0 && entryFound
          @chiika.logger.script("[yellow](#{@name}-Manga-Search) Search returned 1 entry")
          mangaExtraView.setData(newMangaEntry,'mal_id').then (args) =>
            if args.rows > 0
              @chiika.logger.script("[yellow](#{@name}-Manga-Search) Updated #{args.rows} entries.")
              mangaExtraView.reload().then =>
                callback?({ success: true, entry: newMangaEntry, updated: args.rows })
        else if !entryFound
          callback({ success: false, response: "Search failed.",updated: 0 })


      #
      # http://myanimelist.net/includes/ajax.inc.php?id=id&t=64
      #
      @searchExtended 'manga', mangaEntry.mal_id, (result) ->

        if result?
          newMangaEntry = {}
          newMangaEntry.mal_id = mangaEntry.mal_id
          newMangaEntry.mangaGenres = result.genres
          newMangaEntry.mangaScoreAverage = result.score
          newMangaEntry.mangaRanked = result.rank
          newMangaEntry.mangaPopularity = result.popularity
          newMangaEntry.scoredBy = result.scoredBy

          mangaExtraView.setData(newMangaEntry,'mal_id').then (args) =>
            @chiika.logger.script("[yellow](#{@name}-Anime-Search-Extended) Updated #{args.rows} entries.")
            mangaExtraView.reload().then =>
              callback?({ success: true, entry: newMangaEntry, updated: args.rows})
        else
          callback?({ success: false, response: "No Entry" })

      #
      # Manga Page Scraping
      #
      @mangaPageScrape mangaEntry.mal_id, (result) ->

        if result?
          newMangaEntry = {}
          newMangaEntry.mal_id = mangaEntry.mal_id
          newMangaEntry.mangaJapanese = result.japanese
          newMangaEntry.mangaPublished = result.published
          newMangaEntry.mangaCharacters = result.characters
          newMangaEntry.mangaSerialization = result.serialization
          newMangaEntry.mangaAuthor = result.author

          mangaExtraView.setData(newMangaEntry,'mal_id').then (args) =>
            @chiika.logger.script("[yellow](#{@name}-Manga-Mal-Scrape) Updated #{args.rows} entries.")
            mangaExtraView.reload().then =>
              callback?({ success: true, entry: newMangaEntry, updated: args.rows })
        else
          callback?({ success: false, response: "No Entry", updated: 0 })


  getMangaDetailsLayout: (id) ->
    entry = _find @mangalist, (o) -> o.mal_id == id
    mv    = @getMangaValues(entry)


    if mv.synonyms?
      mv.synonyms = mv.synonyms.split(";")[0]
    else
      mv.synonyms = ""

    if mv.genres == ""
      mv.genres = mv.synonyms
    else
      genresText = ""
      mv.genres.map (genre,i) => genresText += genre + ","
      mv.genres = genresText

    typeCard =
      name: 'typeMiniCard'
      title: 'Type'
      content: mv.type
      type: 'miniCard'

    serializationCard =
      name: 'serializationMiniCard'
      title: 'Serialization'
      content: mv.serialization
      type: 'miniCard'

    cards = [typeCard]

    if mv.serialization?
      cards.push serializationCard

    userStatusText = ""
    if mv.userStatus == "1"
      userStatusText = "Reading"
    else if mv.userStatus == "2"
      userStatusText = "Completed"
    else if mv.userStatus == "3"
      userStatusText = "On Hold"
    else if mv.userStatus == "4"
      userStatusText = "Dropped"
    else if mv.userStatus == "6"
      userStatusText = "Plan to Read"

    detailsLayout =
      id: mv.id
      title: mv.title
      genres: mv.genres
      list: true
      status:
        items:
          [
            { title: 'Chapters', current: mv.readChapters, total: mv.chapters },
            { title: 'Volumes', current: mv.readVolumes, total: mv.volumes }
          ]
        user: mv.userStatus
        series: mv.seriesStatus
        defaultAction: userStatusText
        actions:[
          { name: 'Reading', action: 'status-action-watching', identifier:"1" },
          { name: 'Completed', action: 'status-action-completed', identifier:"2" }
          { name: 'Plan to Read', action: 'status-action-ptw',identifier:"6" },
          { name: 'On Hold', action: 'status-action-onhold',identifier:"3" },
          { name: 'Dropped', action: 'status-action-dropped',identifier:"4" }
        ]
      synopsis: mv.synopsis
      cover: mv.image
      english: mv.english
      voted: mv.scoredBy
      characters: mv.characters
      japanese: mv.japanese
      params:
        author: mv.author
        serialization: mv.serialization
        published: mv.published
      owner: @name
      actionButtons: [
        { name: 'Torrent', action: 'torrent',color: 'lightblue' },
        { name: 'Library', action: 'library',color: 'purple' }
        { name: 'Play Next', action: 'playnext',color: 'teal' }
        { name: 'Search', action: 'search',color: 'green' }
      ]
      scoring:
        type: 'normal'
        userScore: mv.score
        average: mv.averageScore
      miniCards: cards


  getAnimeDetailsLayout: (id) ->
    entry = _find @animelist, (o) -> o.mal_id == id

    av    = @getAnimeValues(entry)

    if av.synonyms?
      av.synonyms = av.synonyms.split(";")[0]
    else
      av.synonyms = ""

    if av.synopsis?
      #Replace html stuff
      av.synopsis = av.synopsis.split("[i]").join("<i>")
      av.synopsis = av.synopsis.split("[/i]").join("</i>")



    typeCard =
      name: 'typeMiniCard'
      title: 'Type'
      content: av.typeText
      type: 'miniCard'

    seasonCard =
      name: 'seasonMiniCard'
      title: 'Season'
      content: av.season
      type: 'miniCard'

    sourceCard =
      name: 'sourceMiniCard'
      title: 'Source'
      content: av.source
      type: 'miniCard'

    if av.studio?
      studioCard =
        name: 'studioMiniCard'
        title: 'Studio'
        content: av.studio.name
        type: 'miniCard'

    durationCard =
      name: 'durationMiniCard'
      title: 'Duration'
      content: av.duration
      type: 'miniCard'

    cards = [typeCard,seasonCard]

    if av.source != ""
      cards.push sourceCard

    if av.studio?
      cards.push studioCard

    if av.duration != ""
      cards.push durationCard

    if av.genres == ""
      av.genres = av.synonyms
    else
      genresText = ""
      av.genres.map (genre,i) => genresText += genre + ","
      av.genres = genresText


    userStatusText = ""
    if av.userStatus == "1"
      userStatusText = "Watching"
    else if av.userStatus == "2"
      userStatusText = "Completed"
    else if av.userStatus == "3"
      userStatusText = "On Hold"
    else if av.userStatus == "4"
      userStatusText = "Dropped"
    else if av.userStatus == "6"
      userStatusText = "Plan to Watch"

    detailsLayout =
      id: av.id
      title: av.title
      genres: av.genres
      list: true
      status:
        items:
          [
            { title: 'Episodes', current: av.watchedEpisodes, total: av.totalEpisodes },
          ]
        user: av.userStatus
        series: av.seriesStatus
        defaultAction: userStatusText
        actions:[
          { name: 'Watching', action: 'status-action-watching', identifier:"1" },
          { name: 'Completed', action: 'status-action-completed', identifier:"2" }
          { name: 'Plan to Watch', action: 'status-action-ptw',identifier:"6" },
          { name: 'On Hold', action: 'status-action-onhold',identifier:"3" },
          { name: 'Dropped', action: 'status-action-dropped',identifier:"4" }
        ]
      synopsis: av.synopsis
      cover: av.image
      english: av.english
      voted: av.scoredBy
      characters: av.characters
      owner: @name
      actionButtons: [
        { name: 'Torrent', action: 'torrent',color: 'lightblue' },
        { name: 'Library', action: 'library',color: 'purple' }
        { name: 'Play Next', action: 'playnext',color: 'teal' }
        { name: 'Search', action: 'search',color: 'green' }
      ]
      scoring:
        type: 'normal'
        userScore: av.score
        average: av.averageScore
      miniCards: cards
  #
  # In the @createViewAnimelist, we created 5 tab
  # Here we supply the data of the tabs
  # The format is { name: 'tabname', data: [] }
  # The data array has to follow the grid rules in order to appear in the grid correctly.
  # Also they need to have a unique ID
  # For animeList object, see myanimelist.net/malappinfo.php?u=arkenthera&type=anime&status=all
  setAnimelistTabViewData: (animeList,view) ->

    commonFormatList = []
    _forEach animeList, (anime) =>
      commonFormatList.push @animeToCommonFormat(anime)

    view.setDataArray(commonFormatList)
  #
  # In the @createViewAnimelist, we created 5 tab
  # Here we supply the data of the tabs
  # The format is { name: 'tabname', data: [] }
  # The data array has to follow the grid rules in order to appear in the grid correctly.
  # Also they need to have a unique ID
  # For animeList object, see myanimelist.net/malappinfo.php?u=arkenthera&type=anime&status=all
  setMangalistTabViewData: (mangaList,view) ->
    commonFormatList = []
    _forEach mangaList, (anime) =>
      commonFormatList.push @mangaToCommonFormat(anime)

    view.setDataArray(commonFormatList)

  #
  #
  #
  updateViewAndRefresh: (viewName,newEntry,key,callback) ->
    view = @chiika.viewManager.getViewByName(viewName)
    view.setData(newEntry,'mal_id').then =>
      callback?({ success: true,updated: 1 })

  #
  #
  #
  updateProgress:(id,type,newProgress,callback) ->
    @chiika.logger.script("Updating #{type} progress - #{id} - to #{newProgress}")
    switch type
      when 'anime'
        animeEntry = _find @animelist, (o) -> (o.mal_id) == id
        if animeEntry?
          animeEntry.animeWatchedEpisodes = newProgress
          @updateAnime animeEntry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_animelist',animeEntry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", response: result.response, errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request.", response: result.response })


      when 'manga'
        mangaEntry = _find @mangalist, (o) -> (o.mal_id) == id
        if mangaEntry?
          mangaEntry.mangaUserReadVolumes = newProgress.volumes
          mangaEntry.mangaUserReadChapters = newProgress.chapters

          @updateManga mangaEntry, (result) =>
            if result.success
              if newProgress.type == 'Chapters'
                @saveMangaHistory('chapters',mangaEntry)
              else
                @saveMangaHistory('volumes',mangaEntry)

              @updateViewAndRefresh 'myanimelist_mangalist',mangaEntry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })


  #
  #
  #
  updateScore:(id,type,newScore,callback) ->
    onUpdateView = (result) =>
      if result.updated > 0
        callback({ success: true, updated: result.updated })
      else
        callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })


    @chiika.logger.script("Updating #{type} score - #{id} - to #{newScore}")
    switch type
      when 'anime'
        animeEntry = _find @animelist, (o) -> (o.mal_id) == id
        if animeEntry?
          animeEntry.animeScore = newScore
          @updateAnime animeEntry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_animelist',animeEntry,'mal_id', (result) =>
                onUpdateView(result)
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })


      when 'manga'
        mangaEntry = _find @mangalist, (o) -> (o.mal_id) == id
        if mangaEntry?
          mangaEntry.mangaScore = newScore
          @updateManga mangaEntry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_mangalist',mangaEntry,'mal_id', (result) =>
                onUpdateView(result)
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })

  #
  #
  #
  updateStatus:(id,type,newStatus,callback) ->
    @chiika.logger.script("Updating #{type} status - #{id} - to #{newStatus}")

    entry = { }
    newTabName = ""
    oldTabName = ""

    switch type
      when 'anime'
        entry = _find @animelist, (o) -> (o.mal_id) == id
      when 'manga'
        entry = _find @mangalist, (o) -> (o.mal_id) == id

    switch type
      when 'anime'
        if entry?
          # Update the entry's status
          entry.animeUserStatus = newStatus

          @updateAnime entry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_animelist',entry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })

      when 'manga'
        if entry?
          # Update the entry's status
          entry.mangaUserStatus = newStatus

          @updateManga entry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_mangalist',entry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })

  #
  #
  #
  getAnimeValues: (entry) ->
    extra = _find @animeextra, (o) -> o.mal_id == entry.mal_id
    findInAnimelist = _find @animelist, (o) -> o.mal_id == entry.mal_id

    if !entry.mal_id?
      chiika.logger.error("You are trying to access an entry without mal_id. Excuse me?")

    if findInAnimelist?
      list = true
    else
      list = false

    if !extra?
      extra = entry

    title               = entry.animeTitle ? ""                       #MalApi
    synonyms            = entry.animeSynonyms ? ""                    #MalApi
    type                = entry.animeType ? ""                        #MalApi
    totalEpisodes       = entry.animeTotalEpisodes ? "0"              #MalApi
    seriesStatus        = entry.animeSeriesStatus ? "0"               #MalApi
    seriesStartDate     = entry.animeStartDate ? ""                   #MalApi
    seriesEndDate       = entry.animeEndDate ? ""                     #MalApi
    image               = entry.animeImage ? "le_default_image"       #MalApi
    watchedEpisodes     = entry.animeWatchedEpisodes ? "0"            #MalApi
    userStartDate       = entry.animeUserStartDate ? ""               #MalApi
    userEndDate         = entry.animeUserEndDate ? ""                 #MalApi
    score               = entry.animeScore ? "0.0"                    #MalApi
    userStatus          = entry.animeUserStatus ? "0"                 #MalApi
    userRewatching      = entry.animeUserRewatching ? ""              #MalApi
    userRewatchingEp    = entry.animeUserRewatchingEp ? ""            #MalApi
    lastUpdated         = entry.animeLastUpdated ? ""                 #MalApi
    tags                = entry.animeUserTags ? ""                    #MalApi
    averageScore        = extra.animeScoreAverage ? "-"               #Ajax.inc
    ranked              = extra.animeRanked ? ""                      #Ajax.inc
    genres              = extra.animeGenres ? ""                      #Ajax.inc
    synopsis            = extra.animeSynopsis ? ""                    #Search
    english             = extra.animeEnglish ? ""                     #Search
    popularity          = extra.animePopularity ? ""                  #Ajax.inc
    scoredBy            = extra.scoredBy ? "0"                        #Ajax.inc
    studio              = extra.animeStudio ? null                    #PageScrape
    broadcastDate       = extra.animeBroadcast ? ""                   #PageScrape
    aired               = extra.animeAired ? ""                       #PageScrape
    japanese            = extra.animeJapanese ? ""                    #PageScrape
    source              = extra.animeSource ? ""                      #PageScrape
    duration            = extra.animeDuration ? ""                    #PageScrape
    characters          = extra.animeCharacters ? []                  #PageScrape


    # Change the type from a number to a common format
    typeText = "Unknown"
    if type == "1"
      typeText = "TV"
    if type == "2"
      typeText = "OVA"
    if type == "3"
      typeText = "Movie"
    if type == "4"
      typeText = "Special"
    if type == "5"
      typeText = "ONA"
    if type == "6"
      typeText = "Music"

    # Change the season from date to text
    startDate = entry.animeStartDate

    if startDate?
      parts = startDate.split("-");
      year = parts[0];
      month = parts[1];

      iMonth = parseInt(month);

      season = "Unknown"
      if iMonth > 0 && iMonth < 4
        season =  "Winter " + year
      if iMonth > 3 && iMonth < 7
        season =  "Spring " + year
      if iMonth > 6 && iMonth < 10
        season =  "Summer " + year
      if iMonth > 9 && iMonth <= 12
        season = "Fall " + year

    # change last updated from unix timestamp to text
    date = moment.unix(parseInt(lastUpdated))
    now = moment()
    diffSeconds = Math.floor(moment.duration(now.diff(date)).asSeconds())
    diffMinutes = Math.floor(moment.duration(now.diff(date)).asMinutes())
    diffHours = Math.floor(moment.duration(now.diff(date)).asHours())
    diffDays = Math.floor(moment.duration(now.diff(date)).asDays())
    diffWeeks = Math.floor(moment.duration(now.diff(date)).asWeeks())
    diffMonths = Math.floor(moment.duration(now.diff(date)).asMonths())
    diffYears = Math.floor(moment.duration(now.diff(date)).asYears())

    lastUpdatedText = "a moment ago"

    if diffMinutes > 0
      lastUpdatedText = "#{diffMinutes} minutes ago"


    if diffHours > 0
      lastUpdatedText = "#{diffHours} hours ago"

    if diffDays > 0
      lastUpdatedText = "#{diffDays} days ago"

    if diffWeeks > 0
      lastUpdatedText = "#{diffWeeks} weeks ago"

    if diffMonths > 0
      lastUpdatedText = "#{diffMonths} months ago"

    if diffYears > 0
      lastUpdatedText = "#{diffYears} years ago"

    lastUpdatedText += " - " + lastUpdated

    anime =
      id: entry.mal_id
      list: list
      title: title
      synonyms: synonyms
      type: type
      totalEpisodes: totalEpisodes
      seriesStatus: seriesStatus
      seriesStartDate: seriesStartDate
      seriesEndDate: seriesEndDate
      image: image
      watchedEpisodes: watchedEpisodes
      userStartDate: userStartDate
      userEndDate: userEndDate
      score: score
      userStatus: userStatus
      userRewatching: userRewatching
      userRewatchingEp: userRewatchingEp
      lastUpdated: lastUpdated
      lastUpdatedText: lastUpdatedText
      tags: tags
      typeText: typeText
      season: season
      score: score
      averageScore: averageScore
      ranked: ranked
      genres: genres
      synopsis: synopsis
      english: english
      popularity: popularity
      scoredBy: scoredBy
      studio: studio
      broadcastDate: broadcastDate
      aired: aired
      japanese: japanese
      source: source
      duration: duration
      characters: characters

  #
  #
  #
  getMangaValues: (entry) ->
    extra = _find @mangaextra, (o) -> o.mal_id == entry.mal_id

    if !extra?
      extra = {}


    title               = entry.mangaTitle ? ""                       #MalApi
    synonyms            = entry.mangaSynonyms ? ""                    #MalApi
    type                = entry.mangaType ? ""                        #MalApi
    seriesStatus        = entry.mangaSeriesStatus ? "0"               #MalApi
    volumes             = entry.mangaSeriesVolumes ? "0"              #MalApi
    chapters            = entry.mangaSeriesChapters ? "0"             #MalApi
    seriesStart         = entry.mangaSeriesStart ? ""                 #MalApi
    seriesEnd           = entry.mangaSeriesEnd ? ""                   #MalApi
    image               = entry.mangaImage ? "le_default_image"       #MalApi
    readVolumes         = entry.mangaUserReadVolumes ? "0"            #MalApi
    readChapters        = entry.mangaUserReadChapters ? "0"           #MalApi
    userStart           = entry.mangaUserStart ? ""                   #MalApi
    userEnd             = entry.mangaUserEnd ? ""                     #MalApi
    userStatus          = entry.mangaUserStatus ? "0"                 #MalApi
    score               = entry.mangaScore ? "0.0"                    #MalApi
    tags                = entry.mangaTags ? "0.0"                     #MalApi
    rereading           = entry.mangaUserRereading ? ""               #MalApi
    rereadingChapter    = entry.mangaUserRereadingChapter ? ""        #MalApi
    lastUpdated         = entry.mangaLastUpdated ? "0.0"              #MalApi
    averageScore        = extra.mangaScoreAverage ? "-"               #Ajax.inc
    ranked              = extra.mangaRanked ? ""                      #Ajax.inc
    genres              = extra.mangaGenres ? ""                      #Ajax.inc
    popularity          = extra.mangaPopularity ? ""                  #Ajax.inc
    scoredBy            = extra.scoredBy ? "0"                        #Ajax.inc
    synopsis            = extra.mangaSynopsis ? ""                    #Search
    english             = extra.mangaEnglish ? ""                     #Search
    serialization       = extra.mangaSerialization ? ""               #PageScrape
    published           = extra.mangaPublished ? ""                   #PageScrape
    japanese            = extra.mangaJapanese ? ""                    #PageScrape
    author              = extra.mangaAuthor ? ""                      #PageScrape
    characters          = extra.mangaCharacters ? []                  #PageScrape

    # Change the type from a number to a common format
    typeText = "Unknown"
    if type == "1"
      typeText = "Normal"
    if type == "2"
      typeText = "Novel"
    if type == "3"
      typeText = "Oneshot"
    if type == "4"
      typeText = "Doujinshi"
    if type == "5"
      typeText = "Manwha"
    if type == "6"
      typeText = "Manhua"

    date = moment.unix(parseInt(lastUpdated))
    now = moment()
    diffSeconds = Math.floor(moment.duration(now.diff(date)).asSeconds())
    diffMinutes = Math.floor(moment.duration(now.diff(date)).asMinutes())
    diffHours = Math.floor(moment.duration(now.diff(date)).asHours())
    diffDays = Math.floor(moment.duration(now.diff(date)).asDays())
    diffWeeks = Math.floor(moment.duration(now.diff(date)).asWeeks())
    diffMonths = Math.floor(moment.duration(now.diff(date)).asMonths())
    diffYears = Math.floor(moment.duration(now.diff(date)).asYears())

    lastUpdatedText = "a moment ago"

    if diffMinutes > 0
      lastUpdatedText = "#{diffMinutes} minutes ago"


    if diffHours > 0
      lastUpdatedText = "#{diffHours} hours ago"

    if diffDays > 0
      lastUpdatedText = "#{diffDays} days ago"

    if diffWeeks > 0
      lastUpdatedText = "#{diffWeeks} weeks ago"

    if diffMonths > 0
      lastUpdatedText = "#{diffMonths} months ago"

    if diffYears > 0
      lastUpdatedText = "#{diffYears} years ago"

    lastUpdatedText += " - " + lastUpdated



    manga =
      id: entry.mal_id
      title: title
      synonyms: synonyms
      type: type
      seriesStatus: seriesStatus
      chapters: chapters
      volumes: volumes
      seriesStart: seriesStart
      seriesEnd: seriesEnd
      image: image
      readVolumes: readVolumes
      readChapters: readChapters
      userStart: userStart
      userEnd: userEnd
      userStatus: userStatus
      score: score
      tags: tags
      userRereading: rereading
      userRereadingChapter: rereadingChapter
      lastUpdated: lastUpdated
      lastUpdatedText: lastUpdatedText
      typeText: typeText
      averageScore: averageScore
      ranked: ranked
      genres: genres
      popularity: popularity
      scoredBy: scoredBy
      synopsis: synopsis
      english: english
      serialization: serialization
      japanese: japanese
      author: author
      published:published
      characters: characters
    manga

  #
  #
  #
  animeToCommonFormat: (v) ->
    anime = {}

    anime.mal_id                    = v.series_animedb_id
    anime.animeTitle                = v.series_title
    anime.animeSynonyms             = v.series_synonyms
    anime.animeType                 = v.series_type
    anime.animeTotalEpisodes        = v.series_episodes
    anime.animeSeriesStatus         = v.series_status
    anime.animeStartDate            = v.series_start
    anime.animeEndDate              = v.series_end
    anime.animeImage                = v.series_image
    anime.animeWatchedEpisodes      = v.my_watched_episodes

    anime.animeUserStartDate        = v.my_start_date
    anime.animeUserEndDate          = v.my_finish_date
    anime.animeScore                = parseInt(v.my_score)
    anime.animeUserStatus           = v.my_status
    anime.animeUserRewatching       = v.my_rewatching
    anime.animeUserRewatchingEp     = v.my_rewatching_ep
    anime.animeLastUpdated          = v.my_last_updated
    anime.animeUserTags             = v.my_tags
    anime

  #
  #
  #
  mangaToCommonFormat: (v) ->
    manga = {}

    manga.mal_id                      = v.series_mangadb_id
    manga.mangaTitle                  = v.series_title
    manga.mangaSynonyms               = v.series_synonyms
    manga.mangaSeriesStatus           = v.series_status
    manga.mangaType                   = v.series_type
    manga.mangaSeriesChapters         = v.series_chapters
    manga.mangaSeriesVolumes          = v.series_volumes
    manga.mangaSeriesStart            = v.series_start
    manga.mangaSeriesEnd              = v.series_end
    manga.mangaImage                  = v.series_image
    manga.mangaUserReadChapters       = v.my_read_chapters
    manga.mangaUserReadVolumes        = v.my_read_volumes
    manga.mangaUserStart              = v.my_start_date
    manga.mangaUserEnd                = v.my_finish_date
    manga.mangaScore                  = v.my_score
    manga.mangaUserStatus             = v.my_status
    manga.mangaLastUpdated            = v.my_last_updated
    manga.mangaUserRereading          = v.my_rereadingg # ?
    manga.mangaUserRereadingChapter   = v.my_rereading_chap
    manga.mangaTags                   = v.my_tags

    manga


  #
  #
  #
  buildAnimeXmlForUpdating: (animeEntry) ->
    entry =
      entry:
        episode: animeEntry.animeWatchedEpisodes
        status: animeEntry.animeUserStatus
        score: animeEntry.animeScore
        storage_type: ""
        storage_value: ""
        times_rewatched: ""
        rewatch_value:""
        date_start: ""
        date_finish: ""
        priority: ""
        enable_discussion: ""
        enable_rewatching:""
        comments:""
        fansub_group: ""
        tags:""

    builder = new xml2js.Builder()
    buildXml = builder.buildObject(entry)
    buildXml

  #
  #
  #
  buildMangaXmlForUpdating: (mangaEntry) ->
    entry =
      entry:
        volume: mangaEntry.mangaUserReadVolumes
        chapter: mangaEntry.mangaUserReadChapters
        status: mangaEntry.mangaUserStatus
        score: mangaEntry.mangaScore
        reread_value:""
        date_start: ""
        date_finish: ""
        priority: ""
        enable_discussion: ""
        enable_rereading:""
        comments:""
        scan_group: ""
        retail_volumes: ""
        tags:""

    builder = new xml2js.Builder()
    buildXml = builder.buildObject(entry)
    buildXml


  #
  #
  #
  createViewAnimeExtra: ->
    animeExtraView =
      name: "myanimelist_animeextra"
      owner: @name
      displayName: 'subview'
      displayType: 'subview'
      noUpdate: true
      subview:{}

    @chiika.viewManager.addView animeExtraView


  #
  #
  #
  createViewMangaExtra: ->
    mangaExtraView =
      name: "myanimelist_mangaextra"
      owner: @name
      displayName: 'subview'
      displayType: 'subview'
      noUpdate: true
      subview:{}

    @chiika.viewManager.addView mangaExtraView

  #
  #
  #
  createViewAnimelist: () ->
    defaultView = {
      name: 'myanimelist_animelist',
      displayName: 'Anime List',
      displayType: 'TabGridView',
      owner: @name, #Script name, the updates for this view will always be called at 'owner'
      category: 'MyAnimelist',
      TabGridView: {
        tabList: [
          { name:'al_watching', display: 'Watching' },
          { name:'al_completed', display: 'Completed'},
          { name:'al_onhold', display: 'On Hold'},
          { name:'al_dropped', display: 'Dropped'},
          { name:'al_ptw', display: 'Plan to Watch'}
          ],
        gridColumnList: [
          { name: 'animeTypeText',display: 'Type', sort: 'na', width:'40',align: 'center',headerAlign: 'center' },
          { name: 'animeTitle',display: 'Title', sort: 'str', widthP:'60', align: 'left', headerAlign: 'left' },
          { name: 'animeProgress',display: 'Progress', sort: 'int', widthP:'40', align: 'center',headerAlign: 'center' },
          { name: 'animeScore',display: 'Score', sort: 'int', width:'100',align: 'center',headerAlign: 'center' },
          { name: 'animeScoreAverage',display: 'Avg Score', sort: 'int', width:'100', align: 'center',headerAlign: 'center' },
          { name: 'animeSeason',display: 'Season', sort: 'str', width:'100', align: 'center',headerAlign: 'center'},
          { name: 'animeLastUpdatedText',display: 'Last Updated', sort: 'int', width:'140', align: 'center',headerAlign: 'center' },
          { name: 'animeId',hidden: true }
        ]
      }
     }
    historyView =
      name: 'myanimelist_animelist_history'
      owner: @name
      displayName: 'AnimeList History'
      displayType: 'none'
      noUpdate: true


    @chiika.viewManager.addView defaultView
    @chiika.viewManager.addView historyView




  #
  #
  #
  createViewMangalist: () ->
    defaultView = {
      name: 'myanimelist_mangalist',
      displayName: 'Manga List',
      displayType: 'TabGridView',
      owner: @name, #Script name, the updates for this view will always be called at 'owner'
      category: 'MyAnimelist',
      TabGridView: { #Must be the same name with displayType
        tabList: [
          { name:'ml_reading', display: 'Reading' },
          { name:'ml_completed', display: 'Completed'},
          { name:'ml_onhold', display: 'On Hold'},
          { name:'ml_dropped', display: 'Dropped'},
          { name:'ml_ptr', display: 'Plan to Read'}
          ],
        gridColumnList: [
          { name: 'mangaTitle',display: 'Title', sort: 'str', widthP:'60', align: 'left',headerAlign: 'left' },
          { name: 'mangaProgress',display: 'Progress', sort: 'int', widthP:'40', align: 'center',headerAlign: 'center' },
          { name: 'mangaScore',display: 'Score', sort: 'int', width:'100', align: 'center',headerAlign: 'center' },
          { name: 'mangaScoreAverage',display: 'Avg Score', sort: 'int', width:'100', align: 'center',headerAlign: 'center' },
          { name: 'mangaLastUpdatedText',display: 'Last Updated', sort: 'int', width:'140', align: 'center',headerAlign: 'center' },
          { name: 'mangaId',hidden: true }
        ]
      }
     }
    historyView =
      name: 'myanimelist_mangalist_history'
      owner: @name
      displayName: 'MangaList History'
      displayType: 'none'
      noUpdate: true

    @chiika.viewManager.addView defaultView
    @chiika.viewManager.addView historyView

  importHistoryFromMAL: (type,callback) ->
    userHistoryUrl = "http://myanimelist.net/history/#{@malUser.realUserName}/#{type}"

    historyView = @chiika.viewManager.getViewByName("myanimelist_#{type}list_history")

    if type == 'anime'
      animeIdPlusTitleRegex = /<td class="borderClass"\s><a href="\/anime.php\?id=(.*)">(.*)<\/a> ep.\s<strong>(.*)<\/strong>/g
      dateRegex = /<td class="borderClass"\s\salign="right">\s(.*)<\/td>/g
    else
      animeIdPlusTitleRegex = /<td class="borderClass"\s><a href="\/manga.php\?id=(.*)">(.*)<\/a> chap.\s<strong>(.*)<\/strong>/g
      dateRegex = /<td class="borderClass"\s\salign="right">\s(.*)<\/td>/g

    onRequestReturn = (error,response,body) =>
      idTitleMap = []

      while idtitleMatch = animeIdPlusTitleRegex.exec body
        id = idtitleMatch[1]
        title = idtitleMatch[2]
        ep = idtitleMatch[3]

        if type == 'anime'
          idTitleMap.push { id: id, title: title,ep: ep }
        else
          idTitleMap.push { id: id, title: title,chapter: ep }

      counter = 0
      while dateMatch = dateRegex.exec body
        date = dateMatch[1]

        idTitleMap[counter].updated = date
        counter++


      historyData = []
      counter = 0
      _forEach idTitleMap, (history) =>
        time = history.updated
        momentDate = {}
        # Do some tests
        indexOfMinutes = time.indexOf 'minutes ago'
        indexOfHours = time.indexOf 'hours ago'
        indexOfYesterday = time.indexOf 'Yesterday'
        indexOfSpace = time.indexOf ' '
        indexOfComma = time.indexOf ','
        indexOfColon = time.indexOf ':'

        if indexOfMinutes >= 0
          digitCount = indexOfSpace

          minute = time.substring(0,digitCount)
          momentDate = moment().subtract(parseInt(minute),'minutes')


        if indexOfHours >= 0
          digitCount = indexOfSpace

          hour = time.substring(0,digitCount)
          momentDate = moment().subtract(parseInt(hour),'hours')

        if indexOfYesterday >= 0
          hourDigitCount = indexOfColon - (indexOfComma + 1)
          hour  = time.substring(indexOfComma + 1,indexOfComma + 1 + hourDigitCount)
          minute = time.substring( indexOfColon + 1, indexOfColon + 1 + 2)
          momentDate = moment().subtract(1,'days')
          momentDate.set('hour',parseInt(hour))
          momentDate.set('minute',parseInt(minute))

        if indexOfMinutes == -1 && indexOfHours == -1 && indexOfYesterday == -1
          digits       = indexOfComma - indexOfSpace - 1
          month = time.substring(0,indexOfSpace)
          day = time.substring(indexOfSpace + 1,indexOfSpace+digits+1)

          hourDigitCount = indexOfColon - (indexOfComma + 1)
          hour  = time.substring(indexOfComma + 1,indexOfComma + 1 + hourDigitCount)
          minute = time.substring( indexOfColon + 1, indexOfColon + 1 + 2)

          momentDate = moment("#{moment().year()} #{month} #{day} #{hour} #{minute}",'YYYY MMM DD HH mm')
        if momentDate.isValid()
          if historyView?
            if type == 'anime'
              historyItem =
                history_id: counter
                updated: momentDate.valueOf()
                id: history.id
                episode: history.ep
            else
              historyItem =
                history_id: counter
                updated: momentDate.valueOf()
                id: history.id
                chapters: history.chapter
            historyData.push historyItem
            counter++
      historyView.clear().then =>
        historyView.setDataArray(historyData).then(callback)




    @chiika.makeGetRequest userHistoryUrl,null,onRequestReturn

  importHistoryFromTaiga: ->
    # Optional - Win Only - Import Taiga history
    # Path : %AppData%/Taiga/user/userName@service/history.xml
    historyFile = path.join process.env.CHIIKA_APPDATA, 'Taiga', 'data','user',"#{@malUser.realUserName}@myanimelist",'history.xml'

    if @chiika.utility.fileExists historyFile
      historyData = @chiika.utility.readFileSync historyFile

      indexOfHistoryElement = historyData.indexOf('<history>')
      historyData =  historyData.substring(indexOfHistoryElement,historyData.length)

      @chiika.parser.parseXml(historyData).then (result) =>
        historyXml  = result
        _forEach historyXml.history.items.item, (item) =>
          convertToMoment = moment(item.time)

          if convertToMoment.isValid()
            id = item.anime_id
            episode = item.episode
            time = convertToMoment.valueOf()

            historyView = @chiika.viewManager.getViewByName('myanimelist_animelist_history')

            if historyView?
              historyData = historyView.getData()

              historyItem =
                history_id: historyData.length
                updated: time
                id: id
                episode: episode
              historyView.setData( historyItem, 'updated')
