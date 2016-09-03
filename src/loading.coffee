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
anime = require 'animejs'

#Views

module.exports = React.createClass
  componentDidMount: () ->
    anime({
      targets: '.anime'+name,
      scale: [0.5,0.7],
      duration: 800,
      direction: 'alternate'
      easing: 'easeInQuart',
      loop: true,
      delay: (el,index) ->
        return index*200
    })

  render: () ->
    (<div className="loading-small">
      <div>
        <svg version="1.1" id="Layer_1" x="0px" y="0px" width="480px" height="480px" viewBox="0 0 512 512" enableBackground="new 0 0 512 512">
          <path className="chiika-logo-path" fill="none" stroke="#606066" strokeWidth="2" strokeMiterlimit="10" d="M414.396,295.424
          	c53.017-17.232,88.227-58.299,83.431-73.064c-4.02-12.375-29.22-19.558-37.274-21.559c4.922-5.862,21.933-27.388,17.759-40.234
          	c-4.864-14.974-57.698-27.845-110.831-10.575c-14.971,4.866-30.762,15.038-45.601,27.517c6.751-17.307,11.15-34.707,11.15-49.862
          	c0-55.765-28.165-101.953-43.683-101.953c-13.007,0-27.623,21.755-32.016,28.8C253.28,48,238.071,25.164,224.568,25.164
          	c-15.739,0-44.303,46.289-44.303,102.174c0,15.051,4.38,32.313,11.123,49.503c-14.375-11.779-29.568-21.35-43.983-26.035
          	c-53.017-17.231-105.634-4.71-110.429,10.055c-4.019,12.375,12.148,33.004,17.488,39.358c-7.425,1.849-33.837,9.261-38.009,22.107
          	c-4.864,14.974,30.317,56.453,83.449,73.722c17.855,5.804,41.09,6.184,64.279,3.495c-20.875,11.682-40.083,26.033-51.407,41.625
          	c-32.766,45.114-37.121,99.042-24.565,108.166c10.522,7.649,35.13-1.357,42.823-4.474c-0.536,7.636-1.65,35.052,9.273,42.992
          	c12.733,9.254,63.041-11.399,95.878-56.61c9.269-12.761,16.074-30.313,20.747-49.169c4.709,18.033,11.388,34.761,20.32,47.059
          	c32.766,45.114,82.691,65.921,95.246,56.796c10.524-7.648,9.565-33.844,8.979-42.125c7.095,2.872,32.816,12.403,43.74,4.463
          	c12.733-9.254,8.643-63.498-24.194-108.709c-10.936-15.057-29.275-28.912-49.401-40.313
          	C374.291,301.654,396.915,301.106,414.396,295.424z"/>
        </svg>
      </div>
    </div>)
