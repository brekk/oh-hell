"use strict"

_ = require 'lodash'
debug = require('debug') 'oh-hell:game'
Model = require 'ampersand-state'

PlayerCollection = require './player-collection'
Player = require './player'
CardCollection = require './card-collection'

Deck = require './deck'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

Game = Model.extend
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
        remainingTricks: ['number', true, 0]

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

    trumps: (asPile=false)->
        if @trump?.suit?        
            self = @
            pile = @deck.pile.filter((card)->
                return (card.suit is self.trump.suit)
            )
            if asPile
                return pile
            return pile.value()

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

    playerByName: (name)->
        return 

    indexOfPlayer: (player)->
        name = player
        if player instanceof Player
            name = player.name
        out = _(@players.models).map((player, index)->
            if player.getId() is name
                if index isnt 0 # zeroes get compacted
                    return index
                return '*'
            return null
        ).compact().first()
        if out is '*' # so we have to uncompact zeroes
            return 0
        return out

    play: ()->
        @playing = true
        # _.times @totalHands, @dealRound, @
        @round = 0
        @dealRound @round

    dealRound: (roundIndex)->
        try
            self = @
            activePlayersThisHand = []
            debug "THE ROUND HAS BEGUN"
            if @totalPlayers < 2
                throw new Error "A minimum of two players are required to play."
            @dealerIndex = roundIndex % @totalPlayers
            counter = 1
            @playerIndex = @dealerIndex + counter
            @assignDealer()
            @cardsThisRound = @cardsPerHand[roundIndex]
            @remainingTricks = @cardsThisRound
            totalCards = @cardsThisRound * @totalPlayers
            @theBetting = 0
            @betting = []

            announceTheBetting = (model, value)->
                debug 'theBetting has changed to: %s sum: %s', self.betting, self.theBetting
                debug 'valid bets include: %s', self.validBets().join '|'

            @on 'change:theBetting', announceTheBetting
            @on 'change:betting', announceTheBetting

            @players.each (player)->
                # hand models, we're a different breed
                player.hand.remove player.hand.models

            @deck.pile.each (card)->
                card.reset()

            bettors = []
            @allBetsIn = false
            @roundFinished = false

            announcePlayerTurn = (player, cardsInPlay, trump)->
                playerName = player.name
                unless cardsInPlay.length > 0
                    debug "It's now the turn of: %s, and they begin the round.", playerName
                else 
                    debug "It's now the turn of: %s, and they must play %s (if they have it)", playerName, _.first(cardsInPlay).suit
                # if trump?
                #     self.roundStrategyFor player, cardsInPlay, trump

            @on 'turn:player', announcePlayerTurn

            turnEverythingOff = ()->
                self.off 'change:playerIndex', announceWhichPlayerShouldPlay
                self.off 'change:theBetting', announceTheBetting
                self.off 'round:finished', compareCardsAndDeclareWinnerOfRound
                self.off 'card:played', playNextCard
                self.off 'turn:player', announcePlayerTurn

            compareCardsAndDeclareWinnerOfRound = (cards)->
                debug "round over!"
                promise = CardCollection::compareAll cards, self.trump.suit
                success = (winningCard)->
                    debug "winner: %s (%s)", winningCard.readable, winningCard.owner
                    winner = winningCard.ownerObject
                    winner.tricks += 1
                    self.remainingTricks -= 1
                    debug "%s has added 1 trick, and currently has approx. %s points.", winner.name, self.convertTricksToPoints winner
                    _.each cards, (card)->
                        player = card.ownerObject
                        player.hand.remove card
                        card.reset()
                        card.visible = true # the cards aren't in play until the hand is over
                    # players.push winner
                    activePlayersThisHand = []
                    setPlayerTurn(null, winner.name)
                    if self.remainingTricks is 0
                        self.trigger 'hand:finished', true
                    return
                failure = (error)->
                    throw error
                promise.then success, failure

            @on 'round:finished', compareCardsAndDeclareWinnerOfRound

            declarePointsAndWinnerOfHand = ()->
                debug 'computing winner...'
                winner = _(self.players).sortedIndex('tricks').each((player)->
                    player.points = self.convertTricksToPoints player.tricks
                    return player
                ).sortBy('points').first()
                debug "%s is the winner of the round!", winner.name
                debug "%s has %s points.", winner.name, winner.points
                _(self.players).sortedIndex('points').each((player)->
                    console.log "#{player.name} has #{player.points} points."
                ).value()
                self.dealRound roundIndex + 1


            @on 'hand:finished', declarePointsAndWinnerOfHand

            setPlayerTurn = (card, player=null)->
                debug "round played: %s", self.playerIndex
                # if card?.owner?
                #     debug "card played by #{card.owner}: #{card.readable}"
                if self.cardsInPlay.length < self.totalPlayers
                    if player?
                        console.log 'given player', player
                        newIndex = self.indexOfPlayer player
                        if newIndex?
                            self.playerIndex = newIndex
                        else
                            self.incrementPlayerIndex()
                    else
                        self.incrementPlayerIndex()
                self.trigger 'turn:player', self.activePlayer, self.cardsInPlay, self.trump
                return

            @on 'card:played', setPlayerTurn

            @players.each (player)->
                player.on 'card:play', (card)->
                    unless self.allBetsIn
                        throw new Error "Unable to play yet, some players haven't voted."
                    firstCardPlayed = _.first self.cardsInPlay
                    if firstCardPlayed?
                        if (card.suit isnt firstCardPlayed.suit) and card.ownerObject.hand.hasSuit firstCardPlayed.suit
                            debug "#{player.name}, you have to follow suit!"
                            self.trigger "player:mistake", card.owner, firstCardPlayed.suit
                            return
                    card.visible = true
                    activePlayersThisHand.push card.owner
                    # console.log "players who've played this round:", activePlayersThisHand
                    # console.log 'self.totalPlayers', activePlayersThisHand.length, self.totalPlayers
                    if activePlayersThisHand.length is self.totalPlayers
                        self.roundFinished = true
                        self.trigger 'round:finished', self.cardsInPlay
                        return
                    self.trigger 'card:played', card

                player.on 'bet', (bet)->
                    if _.contains bettors, player.name
                        throw new Error "This player (#{player.name} has already bet."
                        return
                    sum = 0
                    addBets = (givenBet)->
                        sum += givenBet
                    _.each self.betting, addBets
                    if (bet + sum) is self.cardsThisRound
                        # Your bet can't add up to the total cards dealt.
                        self.trigger 'bet:again', player, sum
                        return
                    if (bet <= self.cardsThisRound) and (bet >= 0)
                        if (self.theBetting + bet) != totalCards
                            debug "%s bet: %s", player.name, bet
                            self.theBetting += bet
                            player.activeBet = bet
                            self.betting.push bet
                            bettors.push player
                    if bettors.length is self.totalPlayers
                        debug "ALL THE PLAYERS HAVE VOTED."
                        self.allBetsIn = true
                    return

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

    incrementPlayerIndex: ()->
        @playerIndex = (@playerIndex + 1) % @players.length
        return

    decrementPlayerIndex: ()->
        if @playerIndex isnt 0
            @playerIndex = (@playerIndex - 1) % @players.length
            return
        @playerIndex = @players.length - 1
        return

    isTrump: (card)->
        return card.suit is @trump.suit

    validPlays: (givenCard, collection, playToWin=true, visible=false)->
        self = @
        # validPlays: (comparisonCard, playToWin=true, visible=false)->
        if !collection.models? and _.isArray collection
            collection = new CardCollection collection
        plays = collection.validPlays givenCard, playToWin, visible
        if plays.hasSuit
            plays.cards = [_.first plays.cards]
            return plays
        filtered = _.filter plays.cards, (card)->
            return self.isTrump(card)
        if filtered.length isnt 0
            plays.cards = filtered
        return plays

    validBets: ()->
        if @theBetting is 0
            return [0..@cardsThisRound]
        return _.without [0..7], 7 - @theBetting

    convertTricksToPoints: (player)->
        if player.tricks is player.activeBet
            return player.tricks + 10
        return player.tricks

    probability: ()->
        inPlay = @deck.pile.where({visible: true}).value()
        ownedBySomeone = @deck.pile.reject({owner: DECK_OWNER}).value()
        ownedBySomeoneOrInPlay = ownedBySomeone.concat inPlay
        applicator = {
            models: ownedBySomeoneOrInPlay
            pile: _ ownedBySomeoneOrInPlay
        }
        CardCollection::probability.apply applicator, arguments

    roundStrategyFor: (player, cardsInPlay=null, trump=null)->
        unless cardsInPlay?
            cardsInPlay = @cardsInPlay
        unless trump?
            trump = @trump
        firstPlayedCard = _.first cardsInPlay
        validPlays = _.bind player.hand.validPlays, player.hand
        if firstPlayedCard?
            toWin = _.first validPlays(firstPlayedCard, true).cards
            toLose = _.first validPlays(firstPlayedCard, false).cards
            if toWin is toLose
                debug "they should play: #{toWin.readable}"
            else
                debug "they should likely play: #{toWin.readable} to win, or #{toLose.readable} to lose."



Game.Card = require './card'
Game.CardCollection = CardCollection

module.exports = Game