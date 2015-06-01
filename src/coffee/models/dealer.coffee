"use strict"

Model = require 'ampersand-state'
debug = require('debug') 'oh-hell:dealer'
_ = require 'lodash'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

module.exports = Dealer = Model.extend
    deal: (cards, players, per=1)->
        toDeal = cards.slice 0, per * _.size players
        playerCount = 0
        _.each toDeal, (card)->
            player = players[playerCount]
            player.addCard.call player, card
            if playerCount + 1 > _.size(players) - 1
                playerCount = 0
            else
                playerCount += 1
            return
        return