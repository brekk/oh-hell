"use strict"
Model = require 'ampersand-state'
Hand = require './hand'
debug = require('debug') 'oh-hell:player'

_ = require 'lodash'

Dealer = require './dealer'

module.exports = Player = Model.extend
    idAttribute: 'name'
    props:
        name: ['string', true]
        human: ['boolean', true, false]

    session:
        activeBet: ['number', false]
        isDealer: ['boolean', true, false]
        cheater: ['boolean', true, false]
        points: ['number', true, 0]
        tricks: ['number', true, 0]
        lastBet: ['number', true, -1]

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
                if @trumpExists()
                    return @hand.arrange(@collection.parent.trump.suit, true).where({suit: @collection.parent.trump.suit}).value()
                return []

        faceCards:
            deps: [
                'hand'
            ]
            cache: true
            fn: ()->
                return @hand.faceCards()

        trumpFaceCards:
            deps: [
                'trumps'
                'faceCards'
            ]
            cache: true
            fn: ()->
                if @trumpExists()
                    return _(@trumps).filter((c)->
                        return c.isFaceCard()
                    ).value()
                return @faceCards

    deal: (cardsPerHand)->
        if @isDealer
            Dealer::deal.call @, @collection.parent.deck.shuffledPile, @collection.models, cardsPerHand

    addCard: (card)->
        card.owner = @getId()
        card.ownerObject = @
        @hand.addCard card

    trumpExists: ()->
        return @collection?.parent?.trump?.suit?

    playCard: (card)->
        try
            if _.isString card
                debug 'given string "%s"', card
                card = @hand.pile().where({readable: card}).first()
                console.log "card!", card.readable
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
        @lastBet = amount
        @activeBet = amount
        @trigger 'bet', amount
        return @

    rankedCards: ()->
        ranks = {
            C: @faceCards
        }
        if @trumpExists()
            ranks.A = @trumpFaceCards
            ranks.B = @trumps
            trump = @collection.parent.trump
            badCards = (card)->
                if card.isFaceCard()
                    return false
                if card.suit is trump
                    return false
                if card.isUnder 3
                    return true
                return false
            mediocreCards = (card)->
                if card.isFaceCard()
                    return false
                if card.suit is trump
                    return false
                if card.isOver 3
                    return true
                return false
            worseToBetter = @hand.arrange(trump.suit, true, false, false)
            ranks.D = worseToBetter.filter(mediocreCards).value()
            ranks.F = worseToBetter.filter(badCards).value()
        return ranks

    strategyToPlay: ()->
        if @activeBet?
            if @tricks is @activeBet
                return false
        return true

    strategyToBet: ()->
        self = @
        ranked = @rankedCards()
        lengthRanked = _(ranked).map((tier, name)->
            out = {}
            out[name] = tier.length
            return out
        ).reduce((collection, iter)->
            return _.extend collection, iter
        , {})
        debug "length ranked:", lengthRanked
        playToWin = false
        bet = 0
        if @trumpExists()
            game = @collection.parent
            probabilityRanked = _(ranked).map((tier, name)->
                out = {}
                out[name] = self.hand.probability tier, true, 'decimal'
                return out
            ).reduce((collection, iter)->
                return _.extend collection, iter
            , {})
            debug "probability ranked:", probabilityRanked
            if ((lengthRanked.A > lengthRanked.F) or (lengthRanked.B > lengthRanked.F)) and (lengthRanked.A isnt 0 and lengthRanked.B isnt 0)
                playToWin = true
                if (lengthRanked.B > lengthRanked.A) and (lengthRanked.A > 0)
                    debug "ranked by B", lengthRanked.B
                    debug "bet against the trump we've got, we have at least one trump face card and we can try for a run"
                    bet = lengthRanked.B
                else
                    debug "ranked by A", lengthRanked.A
                    debug "bet against our trump face cards"
                    bet = lengthRanked.A
            else if (lengthRanked.F > lengthRanked.A) and (lengthRanked.F > lengthRanked.B)
                debug "ranked by F", lengthRanked.F
                debug "bet zero and slough off everything"
                bet = 0
            else
                playToWin = false
                debug "ranked by D", lengthRanked.D
                debug "bet low and slough off until there's a window"
                bet = (Math.round Math.random() * 1)
        return {
            playToWin: playToWin
            bet: bet
        }