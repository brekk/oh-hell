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
                return [1..7].reverse().concat [1..7]
                # 7 6 5 4 3 2 1 1 2 3 4 5 6 7
                # 0 1 2 3 4 5 6 7 8 9 0 1 2 3
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
        cardsInPlay: ['array', false]

    derived:

        totalPlayers:
            deps: [
                'players'
            ]
            cache: true
            fn: ()->
                return @players.models.length

        activeCards:
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
        index = index % @players.models.length
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

            totalCards = -1
            counter = 1

            setInitialSettings = ()->
                self.cardsInPlay = []
                # self.dealerIndex = roundIndex % self.totalPlayers
                counter = 1
                self.playerIndex = self.dealerIndex + counter
                self.assignDealer()
                self.cardsThisRound = self.cardsPerHand[roundIndex]
                self.remainingTricks = self.cardsThisRound
                totalCards = self.cardsThisRound * self.totalPlayers
                self.theBetting = 0
                self.betting = []
                self.allBetsIn = false
                self.roundFinished = false

            setInitialSettings()

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
            removeListeners = []
            

            turnEverythingOff = ()->
                self.off 'change:theBetting', announceTheBetting
                self.off 'change:betting', announceTheBetting
                self.off 'round:finished', compareCardsAndDeclareWinnerOfRound
                self.off 'hand:finished', declarePoints
                self.off 'card:played', setPlayerTurn
                _.each self.players.models, (player)->
                    player.tricks = 0
                    player.activeBet = 0
                    player.isDealer = false
                    player.off 'card:play'
                    player.off 'bet'
                    return
                return

            resetCards = (cards, visible=true)->
                _.each cards, (card)->
                    player = card.ownerObject
                    if player?.hand?
                        player.hand.remove card
                    card.reset()
                    card.visible = visible # the cards aren't in play until the hand is over
                    return
                return

            announceVisibleCards = ()->
                self.players.each (player)->
                    console.log player.name, "8--->", player.hand.pile().groupBy('visible').map((list, title)->
                        x = {}
                        x[title] = list.length
                        return x
                    ).reduce((x, y)->
                        return _.assign x, y
                    , {})
                return

            compareCardsAndDeclareWinnerOfRound = (cards)->
                debug "round over!"
                promise = CardCollection::compareAll cards, self.trump.suit
                success = (winningCard)->
                    debug "winner: %s (%s)", winningCard.readable, winningCard.owner
                    winner = winningCard.ownerObject
                    winner.tricks += 1
                    self.remainingTricks -= 1
                    debug "%s has added 1 trick, and currently has approx. %s points.", winner.name, self.convertTricksToPoints winner
                    resetCards cards
                    announceVisibleCards()
                    # players.push winner
                    if self.remainingTricks is 0
                        setTimeout ()->
                            self.trigger 'hand:finished', true
                            return
                        , 400
                        return
                    activePlayersThisHand = []
                    setPlayerTurn(null, winner.name)
                failure = (error)->
                    throw error
                promise.then success, failure
                return

            @on 'round:finished', compareCardsAndDeclareWinnerOfRound

            declarePoints = ()->
                _(self.players.models).map((player)->
                    if player.activeBet is player.tricks
                        debug "%s made their bid!", player.name
                    player.points += self.convertTricksToPoints player
                ).value()
                _(self.players.models).sortBy('points').each((player)->
                    debug "%s has %s points.", player.name, player.points
                ).value()
                debug "%s is the current winner of the game!", _(self.players.models).sortBy('points').last().name
                debug "THE ROUND IS OVER!"
                turnEverythingOff()
                resetCards game.deck.models, false
                announceVisibleCards()
                setInitialSettings()
                self.dealRound roundIndex + 1
                return

            @on 'hand:finished', declarePoints

            setPlayerTurn = (card, player=null)->
                debug "lastPlayer: %s", self.activePlayer.name
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
                debug "newPlayer: %s", self.activePlayer.name
                setTimeout ()->
                    self.trigger 'turn:player', self.activePlayer, self.cardsInPlay, self.trump
                    return
                , 400
                return

            @on 'card:played', setPlayerTurn

            alreadyPlayedError = (player)->
                return new Error "#{player.name} has already played this round."
            @players.each (player)->

                playCard = (card)->
                    unless self.allBetsIn
                        throw new Error "Unable to play yet, some players haven't voted."
                    if card?.ownerObject? and card?.owner?
                        playerAlreadyPlayedCardThisRound = _(self.cardsInPlay).where({owner: card.owner})[0]
                        if playerAlreadyPlayedCardThisRound? and playerAlreadyPlayedCardThisRound
                            throw alreadyPlayedError player
                            return
                        if _.contains activePlayersThisHand, card.owner
                            throw alreadyPlayedError player
                            return
                    firstCardPlayed = _.first self.cardsInPlay
                    if firstCardPlayed?
                        if (card.suit isnt firstCardPlayed.suit) and card.ownerObject.hand.hasSuit firstCardPlayed.suit
                            debug "#{player.name}, you have to follow suit!"
                            self.trigger "player:mistake", card.owner, firstCardPlayed.suit
                            return
                    card.visible = true
                    self.cardsInPlay.push card
                    activePlayersThisHand.push card.owner
                    # console.log "players who've played this round:", activePlayersThisHand
                    # console.log 'self.totalPlayers', activePlayersThisHand.length, self.totalPlayers
                    if activePlayersThisHand.length is self.totalPlayers
                        self.roundFinished = true
                        cardsInPlay = self.cardsInPlay
                        self.cardsInPlay = []
                        setTimeout ()->
                            self.trigger 'round:finished', cardsInPlay
                            return
                        , 400
                        return
                    self.trigger 'card:played', card
                    return

                makeABet = (bet)->
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

                player.on 'card:play', playCard
                player.on 'bet', makeABet
                removeListeners.push ()->
                    player.off 'card:play', playCard
                    player.off 'bet', makeABet
                    return
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

    tricks: ()->
        return @players.tricks()



Game.Card = require './card'
Game.CardCollection = CardCollection

module.exports = Game