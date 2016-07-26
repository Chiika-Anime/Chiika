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

path                    = require 'path'
fs                      = require 'fs'
_                       = require 'lodash'
coffee                  = require 'coffee-script'
string                  = require 'string'
{Emitter}               = require 'event-kit'
ChiikaPublicApi         = require './chiika-public'
moment                  = require 'moment'


module.exports = class APIManager
  compiledUserScripts: []
  constructor: ->
    global.api = this

    @scriptsDir = path.join(application.getAppHome(),"Scripts")
    @scriptsCacheDir = path.join(application.getAppHome(),"Cache","Scripts")

    @watchScripts()


  #
  # Script compile event
  # @param {String} script The path of compiled script
  # @return
  onScriptCompiled: (script) ->
    rScript = require(script)

    @chiikaApi = new ChiikaPublicApi( { logger: chiika.logger, db: dbManager })
    rScript(@chiikaApi)



  #
  # Compile user scripts
  # @return
  compileUserScripts: ->
    chiika.logger.info "Compiling user scripts..."
    #Look for coffee files
    fs.readdir @scriptsDir,(err,files) =>
      _.forEach files, (v,k) =>
        chiika.logger.info "Compiling " + v
        stripExtension = string(v).chompRight('.coffee').s
        fs.readFile path.join(@scriptsDir,v),'utf-8', (err,data) =>
          try
            compiledString = coffee.compile(data)
            chiika.logger.info "Compiled " + v
          catch
            chiika.logger.error("Error compiling user-script " + v)
            throw console.error "Error compiling user-script"
          cachedScriptPath = path.join(@scriptsCacheDir,stripExtension + moment().valueOf() + '.chiikaJS')
          fs.writeFile cachedScriptPath,compiledString, (err) =>
            if err
              chiika.error "Error occured while writing compiled script to the file."
              throw err
            chiika.logger.verbose("Cached " + v + " " + moment().format('DD/MM/YYYY HH:mm'))
            @compiledUserScripts.push cachedScriptPath
            @onScriptCompiled cachedScriptPath

  #
  # Watch the changes of the scripts and recompile
  #
  watchScripts: ->
    fs.readdir @scriptsDir,(err,files) =>
      _.forEach files, (v,k) =>
        fs.watchFile path.join(@scriptsDir,v), (eventType,filename) =>
          chiika.logger.info "----------------------------------------------"
          chiika.logger.info "Recompiling..."
          @compiledUserScripts = []
          @compileUserScripts()
