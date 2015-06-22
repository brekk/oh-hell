_ = require 'lodash'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

Card = require('./card').Card
debug = require('debug') 'hell:deck'

Deck = ()->
    "use strict"
    cards = _.map THE_SUITS, (suit)->
        debug "generating suit: %s", suit
        return _.map [2..14], (value)->
            c = new Card value, suit
            return c
    return _(cards).flatten().shuffle().value()

module.exports = Deck