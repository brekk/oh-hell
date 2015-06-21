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
        @hand.addCard card

    trumpExists: ()->
        return @collection?.parent?.trump?.suit?

    play: (card)->
        try
            if _.isString card
                debug 'given string "%s"', card
                card = @hand.pile().where({readable: card}).first()
            unless card?
                throw new TypeError "Expected string or card."
            if !(@hand.has card) or (card.owner isnt @name)
                unless @cheater
                    throw new Error "Unable to play a card I don't own."
                    @cheater = true
            debug "%s is playing card %s", @name, card.readable
            @trigger 'card:play', card
            return
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
        unless _.isNumber amount
            throw new TypeError "Expected bet to be a number."
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
            aceTrump = _.where ranks.A, {value: 14}
            if 0 < _.size aceTrump
                ranks.AA = aceTrump
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
        rank = _(ranked).map((tier, name)->
            out = {}
            out[name] = tier.length
            return out
        ).reduce((collection, iter)->
            return _.extend collection, iter
        , {})
        debug "length ranked:", rank
        playToWin = false
        bet = 0
        if @trumpExists()
            game = @collection.parent
            # probabilityRanked = _(ranked).map((tier, name)->
            #     out = {}
            #     out[name] = self.hand.probability tier, true, 'decimal'
            #     return out
            # ).reduce((collection, iter)->
            #     return _.extend collection, iter
            # , {})
            # debug "probability ranked:", probabilityRanked

            overF = (rank.A > rank.F) or (rank.B > rank.F)
            overD = (rank.B > rank.D) or (rank.A > rank.D)
            noABZeroes = (rank.A isnt 0 and rank.B isnt 0)

            if rank.AA? or (overF and overD and noABZeroes)
                playToWin = true
                if (rank.B > rank.A) and (rank.A > 0)
                    debug "ranked by B", rank.B
                    bet = rank.B
                    debug "bet against the trump we've got, we have at least one trump face card and we can try for a run (%s)", bet
                else
                    debug "ranked by A", rank.A
                    unless rank.AA?
                        bet = rank.A
                        debug "bet against our trump face cards (%s)", bet
                    else
                        bet = rank.AA
                        debug "we have an ace of trump, bet minimum 1."
            else if (rank.F > rank.A) and (rank.F > rank.B)
                debug "ranked by F", rank.F
                bet = 0
                debug "bet zero and slough off everything (%s)", bet
            else
                playToWin = false
                debug "ranked by D", rank.D
                bet = (Math.round Math.random() * 1)
                debug "bet low and slough off until there's a window (%s)", bet
        return {
            playToWin: playToWin
            bet: bet
        }

    overBid: ()->
        if @tricks? and @activeBet?
            return @tricks > @activeBet
        return false

    underBid: ()->
        if @tricks? and @activeBet?
            return @tricks < @activeBet
        return false