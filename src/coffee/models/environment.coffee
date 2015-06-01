"use strict"
debug = require('debug') 'oh-hell:environment'

SUIT_HEARTS = 'hearts'
SUIT_CLUBS = 'clubs'
SUIT_DIAMONDS = 'diamonds'
SUIT_SPADES = 'spades'

_ = require 'lodash'

THE_SUITS = [
    SUIT_HEARTS
    SUIT_CLUBS
    SUIT_DIAMONDS
    SUIT_SPADES
]

DECK_OWNER = "DECK"

isValidSuit = (s)->
    return _.contains THE_SUITS, s

module.exports = {
    THE_VALUES: [2..14]
    THE_SUITS: THE_SUITS
    DECK_OWNER: DECK_OWNER
    isValidSuit: isValidSuit
}