"use strict"

_ = require 'lodash'
debug = require('debug') 'hell:game'
Deck = require './deck'

Game = (__config__, $bus)->
    debug "generating deck..."
    deck = Deck()
    cardsPerHand = [1..7].reverse().concat [1..7]
    totalHands = 14
    config = _.extend {
        cardsPerHand: cardsPerHand
        totalHands: totalHands
    }, __config__
    if (config.round? and _.isNumber config.round) and (config.round < cardsPerHand.length)
        config.activeCardsThisHand = cardsPerHand[config.round]
        debug "setting activeCardsThisHand: %s", config.activeCardsThisHand
    debug "config", config, cardsPerHand[config.round]
    $bus.push {
        message: 'config'
        config: config
    }
    $bus.push {
        message: 'cards'
        cards: deck
    }

module.exports = Game