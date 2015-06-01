"use strict"

_ = require 'lodash'
debug = require('debug') 'oh-hell:game'
Model = require 'ampersand-state'

PlayerCollection = require './player-collection'
Deck = require './deck'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

module.exports = Game = Model.extend
    props:
        cardsPerHand:
            required: true
            type: 'object'
            default: _.once ()->
                return [0..7].reverse().concat [0..7]
        # 7 6 5 4 3 2 1 0 0 1 2 3 4 5 6 7
        # 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
        totalHands: ['number', true, 16]
    session:
        trump: ['object', false]
        trumpSuit: 
            type: 'string'
            required: false
            values: THE_SUITS
        cardsThisRound: ['number', true, 7]
        deck: ['object', false]
        theBetting: ['number', true, 0]
        playing: ['boolean', true, false]
        lastDealer: ['object', false]
        dealer: ['object', false]
        dealerIndex: ['number', true, 0]
        allBetsIn: ['boolean', true, false]

    collections:
        players: PlayerCollection

    initialize: (attrs, opts)->
        self = @
        @deck = new Deck()
        return @

    addPlayer: (player)->
        unless @playing
            @players.add player

    assignDealer: ()->
        totalPlayers = _.size @players.models
        @dealer = _.get @players.models, @dealerIndex
        @dealer.isDealer = true

    play: ()->
        @playing = true
        # _.times @totalHands, @dealRound, @

    dealRound: (index)->
        try
            self = @
            debug "THE ROUND HAS BEGUN"
            totalPlayers = _.size @players.models
            @dealerIndex = index % totalPlayers
            @assignDealer()
            @cardsThisRound = @cardsPerHand[index]
            totalCards = @cardsThisRound * totalPlayers
            @theBetting = 0

            @on 'change:theBetting', (model, value)->
                debug 'the betting has changed to: %s', value

            @players.each (player)->
                # hand models, we're a different breed
                player.hand.remove player.hand.models

            @deck.pile.each (card)->
                card.owner = DECK_OWNER

            bettors = []
            @allBetsIn = false

            @players.each (player)->
                player.on 'card:play', (card)->
                    unless self.allBetsIn
                        throw new Error "Unable to play yet, some players haven't voted."
                    debug "CARD PLAYED: %s by %s", card.readable, card.owner
                    card.visible = true

                player.on 'bet', (bet)->
                    unless _.contains bettors, player.name
                        console.log "right now zeroes don't count because they don't change theBetting"
                        if (bet <= self.cardsThisRound) and bet >= 0
                            if (self.theBetting + bet) != totalCards
                                self.theBetting += bet
                                bettors.push player
                    else
                        throw new Error "This player (#{player.name} has already bet."
                    if bettors.length is totalPlayers
                        debug "ALL THE PLAYERS HAVE VOTED."
                        self.allBetsIn = true

            @dealer.deal @cardsThisRound
            @trump = @deck.pile.shuffle().filter((c)->
                return c.owner is DECK_OWNER
            ).first()
            @trumpSuit = @trump.suit
            debug "TRUMP: %s", @trump.readable
        catch e
            console.log "Error during dealing", e
            if e.stack?
                console.log e.stack

    isTrump: (card)->
        return card.suit is @trumpSuit