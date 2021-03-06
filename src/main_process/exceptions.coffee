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

ExceptionBase = (message) ->
  chiika.logger.error message

module.exports =
  InvalidParameterException: (message) ->
    @name = "InvalidParameterException"
    @message = message
    ExceptionBase(@message)
  InvalidOperationException: (message) ->
    @name = "InvalidOperationException"
    @message = message
    ExceptionBase(@message)
  RequestErrorException: (error) ->
    @name = "RequestErrorException"
    @message = error.message + " Status Code: #{error.statusCode}"
    ExceptionBase(@message)
