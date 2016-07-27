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

NoSQL           = require 'NoSQL'
path            = require 'path'

DbUsers         = require './db-users'
DbCustom        = require './db-custom'
DbUI            = require './db-ui'
DbView          = require './db-view'

{Emitter}       = require 'event-kit'

_               = require 'lodash'
_when           = require 'when'

module.exports = class DatabaseManager
  usersDb: null
  emitter: null
  promises: []
  constructor: ->
    @emitter = new Emitter
    global.dbManager = this



    #Preload databases
    @usersDb      = new DbUsers { @promises }
    @customDb     = new DbCustom { @promises }
    @uiDb         = new DbUI { @promises }

  onLoad: (callback) ->
    _when.all(@promises).then () => callback()

  # @todo Make it so that this returns same instance with same view name
  createViewDb: (viewName) ->
    chiika.logger.info("[magenta](Database-Manager) Loading new database instance for view #{viewName}")
    return new DbView { viewName: viewName }

  emit: (message) ->
    @emitter.emit message


  on: (message,args...) ->
    @emitter.on message,args...
