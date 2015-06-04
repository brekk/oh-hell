{game, brekk, jimmy} = require './lib/runtime'
_ = require 'lodash'

brekk.bet 0

setTimeout ()->
    brekk.playCard _.first (game.validPlays game.deck.pile.where({visible: true}).first(), brekk.hand).cards
, 3e3