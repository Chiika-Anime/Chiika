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

React = require('react')
{Router,Route,BrowserHistory,Link} = require('react-router')
{BrowserWindow, ipcRenderer,remote} = require 'electron'

_                 = require 'lodash'
path              = require 'path'

#Views

SideMenu = React.createClass
  menuItemsSet: false
  isPendingUiItems: false
  requiresRefresh: true

  getInitialState: ->
    uiItems: []
    categories: []
  componentWillMount: ->
    chiika.ipc.refreshUIData (args) =>
      @refreshSideMenu(args)



  componentDidMount: ->
    @refreshSideMenu(chiika.uiData)

    if requiresRefresh
      @refreshSideMenu(chiika.uiData)
      requiresRefresh = false

  componentDidUpdate: ->
    $(".side-menu-link").click ->
      if !this.classList.contains "active"
        $(".side-menu-link").removeClass "active"
        $(this).toggleClass "active"



  refreshSideMenu: (menuItems) ->
    if @requiresRefresh
      chiika.logger.renderer("SideMenu requires refresh!")

      @state.uiItems       = []
      @state.categories    = []

      chiika.logger.renderer("SideMenu::refreshSideMenu")

      @pendingUiItems = []
      @pendingCategories = []

      _.forEach menuItems, (v,k) =>
        #Add category

        if v.displayType == 'TabGridView' && v.children.length == 0
          return


        if _.indexOf(@pendingCategories, _.find(@pendingCategories, (o) -> return o == v.category )) == -1
          @pendingCategories.push v.category

        if _.indexOf(@pendingUiItems, _.find(@pendingUiItems, (o) -> return v.name == o.name )) == -1
          @pendingUiItems.push v

      if @isMounted()
        @setState { uiItems: @pendingUiItems, categories: @pendingCategories }
        requiresRefresh = false

  renderCategory: (name,i) ->
    <p className="list-title" key={i}>{name}</p>

  renderMenuItem: (item,i) ->
    <Link className="side-menu-link" to="#{item.name}" key={i}><li className="side-menu-li" key={i}>{item.displayName}</li></Link>

  renderMenuItems: (category) ->
    menuItemsOfThisCategory = _.filter(@state.uiItems, (o) ->
      return o.category == category)
    if menuItemsOfThisCategory.length > 0
      menuItemsOfThisCategory.map (menuItem,j) =>
        @renderMenuItem(menuItem,j + 1)

  render: () ->
    (<div className="sidebar">
      <div className="topLeft">
        <div className="logoContainer">
          <img className="chiikaLogo" src="../assets/images/topLeftLogo.png"/>
        </div>
        <Link to="User" className="userArea noDecoration">
          <div className="imageContainer">
            <img id="userAvatar" className="img-circle avatar" src="../assets/images/avatar.jpg"/>
          </div>
          <div className="userInfo">
            Chiika
          </div>
        </Link>
      </div>
      <div className="navigation">
        <ul>
          <Link className="side-menu-link active" to="Home"><li className="side-menu-li">Home</li></Link>
          {
            @state.categories.map (category,i) =>
              <div key={i}>
              {
                @renderCategory(category,i)
              }
              {
                @renderMenuItems(category)
              }
              </div>
          }
        </ul>
      </div>
    </div>)

module.exports = SideMenu
