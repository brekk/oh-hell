"use strict"
Model = require 'ampersand-state'
Hand = require './hand'
debug = require('debug') 'oh-hell:player'

Dealer = require './dealer'

module.exports = Player = Model.extend
    idAttribute: 'name'
    props:
        name: ['string', true]

    session:
        activeBet: ['number', false]
        isDealer: ['boolean', true, false]
        cheater: ['boolean', true, false]

    collections:
        hand: Hand

    derived:
        trumps: 
            deps: [
                'hand'
                'collection.parent.trump.suit'
            ]
            cache: true
            fn: ()->
                if @collection?.parent?.trump?.suit?
                    return @hand.arrange(@collection.parent.trump.suit, true).where({suit: @collection.parent.trump.suit}).value()

    deal: (cardsPerHand)->
        if @isDealer
            Dealer::deal.call @, @collection.parent.deck.shuffledPile, @collection.models, cardsPerHand

    addCard: (card)->
        @hand.addCard card

    playCard: (card)->
        try
            if !(@hand.has card) or (card.owner isnt @name)
                unless @cheater
                    throw new Error "Unable to play a card I don't own."
                    @cheater = true
            debug "%s is playing card %s", @name, card.readable
            @trigger 'card:play', card
        catch e
            console.log "error playing card", e
            if e.stack?
                console.log e.stack

    randomCard: (visible=false, ofSuit=null)->
        pile = @hand.pile().shuffle().where({visible: visible})
        if ofSuit?
            suits = pile.where({suit: ofSuit}).value()
            if suits.length > 0
                return suits[0]
        return pile.first()

    bet: (amount)->
        @activeBet = amount
        @trigger 'bet', amount
        return @