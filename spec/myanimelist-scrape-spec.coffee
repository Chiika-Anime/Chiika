request           = require 'request'
xml2js            = require 'xml2js'
_                 = require 'lodash'
GlobalSetup               = require './global-setup'

Parser                    = require './../src/main_process/parser'

animePageUrl = 'http://myanimelist.net/anime/21'
animeAjaxUrl = 'http://myanimelist.net/includes/ajax.inc.php?id=21&t=64'

pageContents = ""


describe 'Myanimelist Anime Page Parsing',->
  this.timeout(10000)

  animeDetails = null

  before (done) =>
    if pageContents.length == 0
      request {url: animePageUrl},(error,response,body) =>
        pageContents = body
        animeDetails = parser.parseAnimeDetailsMalPage(pageContents)
        done()
    else
      done()

  parser = new Parser()



  it 'Find Studio', () ->
    animeDetails.studio.name.should.be.equal("Toei Animation")
  #
  #
  it 'Find Source', () ->
    animeDetails.source.should.be.equal("Manga")

  #
  it 'Find Japanese', () ->
    animeDetails.japanese.should.be.equal("ONE PIECE")

  #
  it 'Find Broadcast', () ->
    animeDetails.broadcast.should.be.equal("Sundays at 09:30 (JST)")

  #
  it 'Find Duration', () ->
    animeDetails.duration.should.be.equal("24 min.")

  #
  it 'Find Aired', () ->
    animeDetails.aired.should.be.equal("Oct 20, 1999 to ?")

  #
  it 'Find Synopsis', () ->
    animeDetails.synopsis.length.should.be.at.least(5)

  #
  it 'Find Characters', () ->
    animeDetails.characters.length.should.be.at.least(1)


#Skip this because the data could change everyday
describe.skip 'That weird ajax.inc thingy', ->
  animeDetails = null

  before (done) =>
    request {url: animeAjaxUrl},(error,response,body) =>
      pageContents = body
      animeDetails = parser.parseMyAnimelistExtendedSearch(pageContents)
      done()

  parser = new Parser()

  it 'Find Genres', ->
    animeDetails.genres.length.should.be.at.least(7)

  it 'Find Score', ->
    animeDetails.score.should.be.equal('8.59')

  it 'Find Popularity', ->
    animeDetails.popularity.should.be.equal('27')

  it 'Find Rank', ->
    animeDetails.rank.should.be.equal('69')

  it 'Find ScoredBy', ->
    animeDetails.scoredBy.should.be.equal('287,515')
