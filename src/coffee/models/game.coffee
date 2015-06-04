"use strict"

_ = require 'lodash'
debug = require('debug') 'oh-hell:game'
Model = require 'ampersand-state'

PlayerCollection = require './player-collection'
CardCollection = require './card-collection'

Deck = require './deck'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

module.exports = Game = Model.extend
    collections:
        players: PlayerCollection
    props:
        cardsPerHand:
            required: true
            type: 'object'
            default: _.once ()->
                return [0..7].reverse().concat [0..7]
        # 7 6 5 4 3 2 1 0 0 1 2 3 4 5 6 7
        # 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
        totalHands: ['number', true, 16]
        bets: ['array', false]
    session:
        trump: ['object', false]
        cardsThisRound: ['number', true, 7]
        deck: ['object', false]
        theBetting: ['number', true, 0]
        betting: ['array', false]
        playing: ['boolean', true, false]
        lastDealer: ['object', false]
        dealer: ['object', false]
        dealerIndex: ['number', true, 0]
        allBetsIn: ['boolean', true, false]
        roundFinished: ['boolean', true, false]
        round: ['number', true, 0]
        playerIndex: ['number', true, -1]

    derived:
        totalPlayers:
            deps: [
                'players'
            ]
            cache: true
            fn: ()->
                return @players.models.length
        cardsInPlay:
            deps: [
                'deck'
            ]
            cache: false
            fn: ()->
                return @deck.pile.filter((card)->
                    return (card.owner isnt DECK_OWNER) and (card.visible)
                ).value()
        activePlayer:
            deps: [
                'playerIndex'
                'players'
            ]
            cache: false
            fn: ()->
                return @playerAt @playerIndex

    initialize: (attrs, opts)->
        self = @
        @deck = new Deck()
        return @

    addPlayer: (player)->
        unless @playing
            @players.add player

    assignDealer: ()->
        @dealer = @playerAt @dealerIndex
        @dealer.isDealer = true

    playerAt: (index)->
        unless _.isNumber index
            throw new TypeError "Expected index to be a number."
        return _.get @players.models, index

    play: ()->
        @playing = true
        # _.times @totalHands, @dealRound, @
        @round = 0
        @dealRound @round

    dealRound: (index)->
        try
            self = @
            players = []
            debug "THE ROUND HAS BEGUN"
            if @totalPlayers < 2
                throw new Error "A minimum of two players are required to play."
            @dealerIndex = index % @totalPlayers
            counter = 1
            @playerIndex = @dealerIndex + counter
            @assignDealer()
            @cardsThisRound = @cardsPerHand[index]
            totalCards = @cardsThisRound * @totalPlayers
            @theBetting = 0
            @betting = []

            announceTheBetting = (model, value)->
                debug 'the betting has changed to: %s', value

            @on 'change:theBetting', announceTheBetting

            @players.each (player)->
                # hand models, we're a different breed
                player.hand.remove player.hand.models

            @deck.pile.each (card)->
                card.owner = DECK_OWNER

            bettors = []
            @allBetsIn = false
            @roundFinished = false

            announceWhichPlayerShouldPlay = (model, index)->
                console.log "player allowed to play", self.playerAt(index).name

            @on 'change:playerIndex', announceWhichPlayerShouldPlay

            announcePlayerTurn = (player, suit)->
                playerName = player.name
                debug "It's now the turn of: %s, and they must play %s (if they have it)", playerName, suit

            @on 'turn:player', announcePlayerTurn

            turnEverythingOff = ()->
                self.off 'change:playerIndex', announceWhichPlayerShouldPlay
                self.off 'change:theBetting', announceTheBetting
                self.off 'round:finished', compareCardsAndDeclareWinnerOfRound
                self.off 'card:played', playNextCard
                self.off 'turn:player', announcePlayerTurn

            compareCardsAndDeclareWinnerOfRound = (cards)->
                winningCard = CardCollection::compare(cards[0], cards[1], self.trump.suit)
                console.log "winner!", winningCard.readable, winningCard.owner
                # turnEverythingOff()
                activePlayerIndex = _.first _.compact self.players.map((player, index)->
                    if player.getId() is winningCard.owner
                        if index - 1 >= 0
                            return (index - 1) % self.players.length
                        return self.players.length - 1
                    return
                )
                console.log "activePlayerIndex", activePlayerIndex
                self.playerIndex = activePlayerIndex
                players = []
                _.each cards, (card)->
                    player = self.players.where({name: card.owner})[0]
                    player.hand.remove card
                    card.visible = false
                    card.owner = DECK_OWNER
                setPlayerTurn()

            @on 'round:finished', compareCardsAndDeclareWinnerOfRound

            setPlayerTurn = (card)->
                debug "round played: %s", self.playerIndex
                if card?.owner?
                    debug "card played by #{card.owner}: #{card.readable}"
                if self.cardsInPlay.length < self.totalPlayers
                    self.playerIndex = (self.playerIndex + 1) % self.players.length
                    suit = null
                    if card?.suit?
                        suit = card.suit
                    self.trigger 'turn:player', self.activePlayer, suit
                    return
                if self.cardsInPlay.length is self.totalPlayers
                    compareCardsAndDeclareWinnerOfRound self.cardsInPlay

            @on 'card:played', setPlayerTurn

            @players.each (player)->
                player.on 'card:play', (card)->
                    unless self.allBetsIn
                        throw new Error "Unable to play yet, some players haven't voted."
                    debug "CARD PLAYED: %s by %s", card.readable, card.owner
                    card.visible = true
                    players.push card.owner
                    console.log "players who've played this round:", players
                    self.trigger 'card:played', card
                    console.log 'self.totalPlayers', players.length, self.totalPlayers
                    if players.length is self.totalPlayers
                        self.roundFinished = true
                        self.trigger 'round:finished', self.cardsInPlay

                player.on 'bet', (bet)->
                    unless _.contains bettors, player.name
                        if (bet <= self.cardsThisRound) and bet >= 0
                            if (self.theBetting + bet) != totalCards
                                self.theBetting += bet
                                self.betting.push bet
                                bettors.push player
                    else
                        throw new Error "This player (#{player.name} has already bet."
                    if bettors.length is self.totalPlayers
                        debug "ALL THE PLAYERS HAVE VOTED."
                        self.allBetsIn = true

            @dealer.deal @cardsThisRound
            @trump = @deck.pile.shuffle().filter((c)->
                return c.owner is DECK_OWNER
            ).first()
            debug "TRUMP: %s", @trump.readable
            dealtCards = @deck.pile.shuffle().filter((c)-> c.owner isnt DECK_OWNER).sortBy('suit').value()
            @trigger 'cards:dealt', dealtCards
            return
        catch e
            console.log "Error during dealing", e
            if e.stack?
                console.log e.stack

    isTrump: (card)->
        return card.suit is @trump.suit

    validPlays: (givenCard, collection, visible=false)->
        self = @
        # validPlays: (comparisonCard, playToWin=true, visible=false)->
        plays = collection.validPlays givenCard, true, visible
        if plays.hasSuit
            plays.cards = [_.first plays.cards]
            return plays
        filtered = _.filter plays.cards, (card)->
            return self.isTrump(card)
        if filtered.length isnt 0
            plays.cards = filtered
        return plays