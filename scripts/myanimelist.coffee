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


authUrl = 'http://myanimelist.net/api/account/verify_credentials.xml'
animePageUrl = 'http://myanimelist.net/anime/'

getSearchUrl = (type,keywords) ->
  "http://myanimelist.net/api/#{type}/search.xml?q=#{keywords}"

getSearchExtendedUrl = (type,id) ->
  if type == 'manga'
    "http://myanimelist.net/includes/ajax.inc.php?id=#{id}&t=65"
  else
    "http://myanimelist.net/includes/ajax.inc.php?id=#{id}&t=64"

_       = require process.cwd() + '/node_modules/lodash'
_when   = require process.cwd() + '/node_modules/when'
string  = require process.cwd() + '/node_modules/string'
{shell}   = require('electron')


module.exports = class MyAnimelist
  # Description for this script
  # Will be visible on app
  displayDescription: "MyAnimelist"

  # Unique identifier for the app
  #
  name: "myanimelist"

  # Logo which will be seen at the login screen
  #
  logo: '../assets/images/my.png'

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


  # Hummingbird https://github.com/hummingbird-me/hummingbird/wiki/API-v1-Methods#library--get-all-entries
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

           _.assign @malUser, { malAnimeInfo: userInfo }
           @chiika.users.updateUser @malUser

           callback(result)

  #
  #
  #
  getMangalistData: (callback) ->
    if _.isUndefined @malUser
      @chiika.logger.error("User can't be retrieved.Aborting manga list request.")
      callback( { success: false })
    else
      @retrieveLibrary 'manga',@malUser.realUserName, (result) =>
           userInfo = result.library.myanimelist.myinfo

           _.assign @malUser, { malMangaInfo: userInfo }
           @chiika.users.updateUser @malUser

           callback(result)

  #
  # Searches animelist either manga or anime
  #
  search: (type,keywords,callback) ->
    if _.isUndefined @malUser
     @chiika.logger.error("User can't be retrieved.Aborting search request.")
     callback( { success: false })
    else
     onSearchComplete = (error,response,body) =>
       @chiika.parser.parseXml(body)
                     .then (result) =>
                       callback(result.anime.entry)

     @chiika.makeGetRequestAuth getSearchUrl(type,keywords.split(" ").join("+")),{ userName: @malUser.realUserName, password: @malUser.password },null, onSearchComplete


  #
  #
  #
  searchExtended: (type,id,callback) ->
    onSearchComplete = (error,response,body) =>
      callback(@chiika.parser.parseMyAnimelistExtendedSearch(body))

    @chiika.makeGetRequest getSearchExtendedUrl(type,id),null, onSearchComplete


  animePageScrape: (id,callback) ->
    onRequest = (error,response,body) =>
      callback(@chiika.parser.parseAnimeDetailsMalPage(body))

    @chiika.makeGetRequest animePageUrl + id,null,onRequest




  # After the constructor run() method will be called immediately after.
  # Use this method to do what you will
  #
  run: () ->
    @on 'initialize', =>
      @malUser = @chiika.users.getDefaultUser(@name)

      if _.isUndefined @malUser
        @chiika.logger.warn("Default user for myanimelist doesn't exist. If this is the first time launch, you can ignore this.")
      else
        @chiika.logger.info("Default user : #{@malUser.realUserName}")

      animelistView   = @chiika.viewManager.getViewByName('myanimelist_animelist')
      animeExtraView  = @chiika.viewManager.getViewByName('myanimelist_animeextra')

      if animelistView?
        @animelist = animelistView.getData()
        @chiika.logger.script("[yellow](#{@name}) Animelist data length #{@animelist.length} #{@name}")

      if animeExtraView?
        @animeextra = animeExtraView.getData()
        @chiika.logger.script("[yellow](#{@name}) AnimeExtra data length #{@animeextra.length} #{@name}")

        mangalistView = @chiika.viewManager.getViewByName('myanimelist_mangalist')
        if mangalistView?
          @mangalist = mangalistView.getData()
          @chiika.logger.script("[yellow](#{@name}) Mangalist data length #{@mangalist.length} #{@name}")


    # This method will be called if there are no UI elements in the database
    # or the user wants to refresh the views
    @on 'reconstruct-ui', (update) =>
      @chiika.logger.script("[yellow](#{@name}) reconstruct-ui #{@name}")

      @createViewAnimelist()
      @createViewMangalist()
      @createViewAnimeExtra()


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
            @setAnimelistTabViewData(result.library.myanimelist.anime,update.view).then => update.defer.resolve({ success: result.success })
          else
            @chiika.logger.warn("[yellow](#{@name}) view-update has failed.")
            update.defer.resolve({ success: result.success })


      else if update.view.name == 'myanimelist_mangalist'
        @getMangalistData (result) =>
          if result.success
            @setMangalistTabViewData(result.library.myanimelist.manga,update.view).then => update.defer.resolve({ success: result.success })
          else
            update.defer.resolve({ success: result.success })



    @on 'details-layout', (args) =>
      @chiika.logger.script("[yellow](#{@name}) Details-Layout #{args.id}")

      id = args.id

      #If its on the list, it will have this entry
      animeEntry = _.find @animelist, (o) -> (o.mal_id) == args.id

      @handleDetailsRequest id, (response) =>
        animeExtraView = @chiika.viewManager.getViewByName('myanimelist_animeextra')
        @animeextra = animeExtraView.getData()

        if response.success && response.updated > 0
          args.return(@getDetailsLayout(id))

      args.return(@getDetailsLayout(id))

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
        when 'cover-click'
          id = layout.id
          if id?
            result = shell.openExternal("http://myanimelist.net/anime/#{id}")
            args.return({ success:result })
          else
            @onActionError("Need ID for cover-click")

        when 'character-click'
          if !params.id?
            onActionError("Need ID for character-click")
          else
            result = shell.openExternal("http://myanimelist.net/character/#{params.id}")
            args.return({ success:result })

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
              async.push deferUpdate1
              async.push deferUpdate2

              @chiika.requestViewUpdate('myanimelist_animelist',@name,deferUpdate1)
              @chiika.requestViewUpdate('myanimelist_mangalist',@name,deferUpdate2)

              _when.all(async).then =>
                args.return( { success: true })

            newUser = { userName: args.user + "_" + @name,owner: @name, password: args.pass, realUserName: args.user }

            @chiika.parser.parseXml(body)
                         .then (xmlObject) =>
                           @malUser = @chiika.users.getUser(args.user + "_" + @name)

                           _.assign newUser, { malID: xmlObject.user.id }
                           if _.isUndefined @malUser
                             @malUser = newUser
                             @chiika.users.addUser @malUser,userAdded
                           else
                             _.assign @malUser,newUser
                             @chiika.users.updateUser @malUser,userAdded

            #  if chiika.users.getUser(malUser.userName)?
            #    chiika.users.updateUser malUser
            #  else
            #  chiika.users.addUser malUser
          else
            #Login failed, use the callback to tell the app that login isn't succesful.
            #
            args.return( { success: false, response: response })

      @chiika.makePostRequestAuth( authUrl, { userName: args.user, password: args.pass },null, onAuthComplete )


  handleDetailsRequest: (animeId,callback) ->
    @chiika.logger.script("[yellow](#{@name}-Anime-Search) Searching for #{animeId}!")

    animeExtraView = @chiika.viewManager.getViewByName('myanimelist_animeextra')

    animeEntry = _.find @animelist, (o) -> (o.mal_id) == animeId

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
        if _.isArray list
          isArray = true
          _.forEach list, (v,k) =>
            if v.id == animeEntry.mal_id
              newAnimeEntry = searchMatch(v)
              entryFound = true
              return false
        else
          if list.id == animeEntry.mal_id
            newAnimeEntry = searchMatch(list)
            entryFound = true


        if isArray && list.length > 0 && entryFound
          @chiika.logger.script("[yellow](#{@name}-Anime-Search) Search returned #{list.length} entries")
          animeExtraView.setData(newAnimeEntry,'mal_id').then (args) =>
            if args.rows > 0
              @chiika.logger.script("[yellow](#{@name}-Anime-Search) Updated #{args.rows} entries.")
              animeExtraView.reload().then =>
                callback?({ success: true, entry: newAnimeEntry, updated: args.rows })
        else if _.size(list) > 0 && entryFound
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
            @chiika.logger.script("[yellow](#{@name}-Anime-Mal-Scrape) Updated #{args.rows} entries.")
            animeExtraView.reload().then =>
              callback?({ success: true, entry: newAnimeEntry, updated: args.rows })
        else
          callback?({ success: false, response: "No Entry", updated: 0 })



  getDetailsLayout: (id) ->
    entry = _.find @animelist, (o) -> o.mal_id == id
    extra = _.find @animeextra, (o) -> o.mal_id == id

    if !extra?
      extra = {}

    if !entry?
      list = false
    else
      list = true

    title               = entry.animeTitle ? ""                       #MalApi
    score               = entry.animeScore ? "0.0"                    #MalApi
    type                = entry.animeType ? ""                        #MalApi
    season              = entry.animeSeason ? ""                      #MalApi
    score               = parseInt(entry.animeScore) ? 0              #MalApi
    totalEpisodes       = entry.animeTotalEpisodes ? "0"              #MalApi
    watchedEpisodes     = entry.animeWatchedEpisodes ? "0"            #MalApi
    image               = entry.animeImage ? "le_default_image"       #MalApi
    synonyms            = entry.animeSynonyms ? ""                    #MalApi
    userStatus          = entry.animeUserStatus ? "0"                 #MalApi
    seriesStatus        = entry.animeSeriesStatus ? "0"               #MalApi
    averageScore        = (extra.animeScoreAverage) ? "0"             #Ajax.inc
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

    if synonyms?
      synonyms = synonyms.split(";")[0]
    else
      synonyms = ""

    if synopsis?
      #Replace html stuff
      synopsis = synopsis.split("[i]").join("<i>")
      synopsis = synopsis.split("[/i]").join("</i>")



    typeCard =
      name: 'typeMiniCard'
      title: 'Type'
      content: type
      type: 'miniCard'

    seasonCard =
      name: 'seasonMiniCard'
      title: 'Season'
      content: season
      type: 'miniCard'

    sourceCard =
      name: 'sourceMiniCard'
      title: 'Source'
      content: source
      type: 'miniCard'

    if studio?
      studioCard =
        name: 'studioMiniCard'
        title: 'Studio'
        content: studio.name
        type: 'miniCard'

    durationCard =
      name: 'durationMiniCard'
      title: 'Duration'
      content: duration
      type: 'miniCard'

    cards = [typeCard,seasonCard]

    if source != ""
      cards.push sourceCard

    if studio?
      cards.push studioCard

    if duration != ""
      cards.push durationCard

    if genres == ""
      genres = synonyms
    else
      genresText = ""
      genres.map (genre,i) => genresText += genre + ","
      genres = genresText

    detailsLayout =
      id: id
      title: title
      genres: genres
      list: list
      status:
        total: totalEpisodes
        watched: watchedEpisodes
        user: userStatus
        series: seriesStatus
      synopsis: synopsis
      cover: image
      english: english
      voted: scoredBy
      characters: characters
      owner: @name
      actionButtons: [
        { name: 'Torrent', action: 'torrent',color: 'lightblue' },
        { name: 'Library', action: 'library',color: 'purple' }
        { name: 'Play Next', action: 'playnext',color: 'teal' }
        { name: 'Search', action: 'search',color: 'green' }
      ]
      scoring:
        type: 'normal'
        userScore: score
        average: averageScore
      miniCards: cards
  #
  # In the @createViewAnimelist, we created 5 tab
  # Here we supply the data of the tabs
  # The format is { name: 'tabname', data: [] }
  # The data array has to follow the grid rules in order to appear in the grid correctly.
  # Also they need to have a unique ID
  # For animeList object, see myanimelist.net/malappinfo.php?u=arkenthera&type=anime&status=all
  setAnimelistTabViewData: (animeList,view) ->


    watching = []
    ptw = []
    completed = []
    onhold = []
    dropped = []

    matchGridColumns = (v,id) ->

      anime = {}
      type = "Unknown"
      if v.series_type == "1"
        type = "TV"
      if v.series_type == "2"
        type = "OVA"
      if v.series_type == "3"
        type = "Movie"
      if v.series_type == "4"
        type = "Special"
      if v.series_type == "5"
        type = "ONA"
      if v.series_type == "6"
        type = "Music"
      anime.animeType = type
      seriesEpisodes = v.series_episodes

      if seriesEpisodes != "0"
        anime.animeProgress = (parseInt(v.my_watched_episodes) / parseInt(v.series_episodes)) * 100
      else
        anime.animeProgress = 0
      anime.animeProgress = parseInt(anime.animeProgress)
      anime.animeTitle = v.series_title
      anime.animeScore = parseInt(v.my_score)
      anime.animeScoreAverage = "0"
      anime.animeLastUpdated = v.my_last_updated
      anime.animeSeason = v.series_start
      anime.animeImage = v.series_image
      anime.animeSynonyms = v.series_synonyms
      anime.animeEpisodes = v.series_episodes
      anime.animeWatchedEpisodes = v.my_watched_episodes
      anime.animeTotalEpisodes = v.series_episodes
      anime.animeUserStatus = v.my_status
      anime.animeSeriesStatus = v.series_status
      anime.id = id + 1
      anime.mal_id = v.series_animedb_id

      anime

    _.forEach animeList, (v,k) =>
      if v.my_status == "1"
        watching.push matchGridColumns(v,watching.length)
      if v.my_status == "6"
        ptw.push matchGridColumns(v,ptw.length)
      if v.my_status == "2"
        completed.push matchGridColumns(v,completed.length)
      if v.my_status == "3"
        onhold.push matchGridColumns(v,onhold.length)
      if v.my_status == "4"
        dropped.push matchGridColumns(v,dropped.length)



    animelistData = []

    animelistData.push { name: 'watching',data: watching }
    animelistData.push { name: 'ptw',data: ptw }
    animelistData.push { name: 'dropped',data: dropped }
    animelistData.push { name: 'onhold',data: onhold }
    animelistData.push { name: 'completed',data: completed }
    view.setData(animelistData)


  #
  # In the @createViewAnimelist, we created 5 tab
  # Here we supply the data of the tabs
  # The format is { name: 'tabname', data: [] }
  # The data array has to follow the grid rules in order to appear in the grid correctly.
  # Also they need to have a unique ID
  # For animeList object, see myanimelist.net/malappinfo.php?u=arkenthera&type=anime&status=all
  setMangalistTabViewData: (mangaList,view) ->
    reading = []
    ptr = []
    completed = []
    onhold = []
    dropped = []



    matchGridColumns = (v,id) ->
      manga = {}
      type = "Unknown"
      if v.series_type == "1"
        type = "Normal"
      if v.series_type == "2"
        type = "Novel"
      if v.series_type == "3"
        type = "Oneshot"
      if v.series_type == "4"
        type = "Doujinshi"
      if v.series_type == "5"
        type = "Manwha"
      if v.series_type == "6"
        type = "Manhua"

      manga.mangaType = type
      seriesChapters = v.series_chapters

      if seriesChapters != "0"
        manga.mangaProgress = (parseInt(v.my_read_chapters) / parseInt(v.series_chapters)) * 100
      else
        manga.mangaProgress = 0
      manga.mangaTitle = v.series_title
      manga.mangaScore = v.my_score
      manga.mangaScoreAverage = "0"
      manga.mangaLastUpdated = "0"
      manga.id = id + 1
      manga.mal_id = v.series_mangadb_id
      manga

    _.forEach mangaList, (v,k) =>
      if v.my_status == "1"
        reading.push matchGridColumns(v,reading.length)
      if v.my_status == "6"
        ptr.push matchGridColumns(v,ptr.length)
      if v.my_status == "2"
        completed.push matchGridColumns(v,completed.length)
      if v.my_status == "3"
        onhold.push matchGridColumns(v,onhold.length)
      if v.my_status == "4"
        dropped.push matchGridColumns(v,dropped.length)



    mangalistData = []
    mangalistData.push { name: 'reading',data: reading }
    mangalistData.push { name: 'ptr',data: ptr }
    mangalistData.push { name: 'dropped',data: dropped }
    mangalistData.push { name: 'onhold',data: onhold }
    mangalistData.push { name: 'completed',data: completed }
    view.setData(mangalistData)


  createViewAnimeExtra: ->
    animeExtraView =
      name: "myanimelist_animeextra"
      owner: @name
      displayName: 'subview'
      displayType: 'subview'
      subview:{}

    @chiika.viewManager.addView animeExtraView

  createViewAnimelist: () ->
    defaultView = {
      name: 'myanimelist_animelist',
      displayName: 'Anime List',
      displayType: 'TabGridView',
      owner: @name, #Script name, the updates for this view will always be called at 'owner'
      category: 'MyAnimelist',
      TabGridView: {
        tabList: [
          { name:'watching', display: 'Watching' },
          { name:'completed', display: 'Completed'},
          { name:'onhold', display: 'On Hold'},
          { name:'dropped', display: 'Dropped'},
          { name:'ptw', display: 'Plan to Watch'}
          ],
        gridColumnList: [
          { name: 'animeType',display: 'Type', sort: 'na', width:'40',align: 'center',headerAlign: 'center' },
          { name: 'animeTitle',display: 'Title', sort: 'str', widthP:'60', align: 'left', headerAlign: 'left' },
          { name: 'animeProgress',display: 'Progress', sort: 'int', widthP:'40', align: 'center',headerAlign: 'center' },
          { name: 'animeScore',display: 'Score', sort: 'int', width:'100',align: 'center',headerAlign: 'center' },
          { name: 'animeScoreAverage',display: 'Avg Score', sort: 'str', width:'100', align: 'center',hidden:true,headerAlign: 'center' },
          { name: 'animeSeason',display: 'Season', sort: 'str', width:'100', align: 'center',headerAlign: 'center'},
          { name: 'animeLastUpdated',display: 'Season', sort: 'str', width:'100', align: 'center',hidden:true,headerAlign: 'center' },
          { name: 'animeId',hidden: true }
        ]
      }
     }


    @chiika.viewManager.addView defaultView


  createViewMangalist: () ->
    defaultView = {
      name: 'myanimelist_mangalist',
      displayName: 'Manga List',
      displayType: 'TabGridView',
      owner: @name, #Script name, the updates for this view will always be called at 'owner'
      category: 'MyAnimelist',
      TabGridView: { #Must be the same name with displayType
        tabList: [
          { name:'reading', display: 'Reading' },
          { name:'completed', display: 'Completed'},
          { name:'onhold', display: 'On Hold'},
          { name:'dropped', display: 'Dropped'},
          { name:'ptr', display: 'Plan to Read'}
          ],
        gridColumnList: [
          { name: 'mangaType',display: 'Type', sort: 'na', width:'40', align:'center',headerAlign: 'center' },
          { name: 'mangaTitle',display: 'Title', sort: 'str', widthP:'60', align: 'left',headerAlign: 'left' },
          { name: 'mangaProgress',display: 'Progress', sort: 'int', widthP:'40', align: 'center',headerAlign: 'center' },
          { name: 'mangaScore',display: 'Score', sort: 'int', width:'100', align: 'center',headerAlign: 'center' },
          { name: 'mangaScoreAverage',display: 'Avg Score', sort: 'str', width:'100', align: 'center',hidden:true,headerAlign: 'center' },
          { name: 'mangaLastUpdated',display: 'Season', sort: 'str', width:'100', align: 'center',hidden:true,headerAlign: 'center' },
          { name: 'mangaId',hidden: true }
        ]
      }
     }
    @chiika.viewManager.addView defaultView
