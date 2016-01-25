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
#Date: 24.1.2016
#authors: arkenthera
#Description:
#----------------------------------------------------------------------------
React = require 'react'
cn = require './../../../ChiikaNode'

PtwGrid = {
    name   : 'gridPlantoWatchList',
    reorderColumns:true,
    columns: [
      { field: 'icon', caption: '', size: '40px',render:(icon) ->
        '<i class="fa fa-desktop" style="color:'+icon.icon+'"></i>'  },
        { field: 'title', caption: 'Title', size: '40%',resizable: true, sortable: true  },
        { field: 'score', caption: 'Score', size: '10%',resizable: true, sortable: true  },
        { field: 'progress', caption: 'Progress', size: '40%',resizable: true, sortable: true },
        { field: 'season', caption: 'Season', size: '120px',resizable: true, sortable: true  },
    ],
    records: [
    ]
}

#Plan to Watch List
PlantoWatchList = React.createClass
  componentDidMount: ->
    @buildData()
    $ ->
      $("#gridPlantoWatchList").w2grid(PtwGrid)
  componentWillUnmount: ->
    $('#gridPlantoWatchList').w2destroy()
    PtwGrid.records = []
  buildData: ->
    list = cn.getAnimeListByUserStatus(6)
    for val in list
      PtwGrid.records.push val
  render: () ->
    (<div id="gridPlantoWatchList" className="listCommon"></div>);

module.exports = PlantoWatchList
