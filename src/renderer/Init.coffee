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
React = require("React");
ReactDOM = require("react-dom");
Root = require('./components/Root')

ChiikaIsReady = ->
  console.log "Chiika-Node kickin' in!"

  ReactDOM.render(React.createElement(Root), document.getElementById('app'))
  # React.render(<div>start</div>, document.getElementById('app'))


  Helpers = require("./components/Helpers")
  Titlebar = require("./components/Titlebar")

  t = new Titlebar
  t.appendTitlebar()

  Helpers.FadeInOnPageLoad()
  Helpers.RunEverything()

  RouteManager = require './components/RouteManager'
  RouteManager.startSearching()




Chiika = require './ChiikaNode'

#Entry point
Chiika.getReady ChiikaIsReady
