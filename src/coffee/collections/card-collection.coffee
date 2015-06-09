"use strict"

_ = require 'lodash'
Collection = require './base-collection'
Card = require './card'
Fraction = require 'fraction.js'

debug = require('debug') 'oh-hell:card-collection'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

module.exports = CardCollection = Collection.extend
    model: Card
    mainIndex: 'id'
    indexes: ['suit', 'value']
    readable: ()->
        return @pile().pluck('readable').value()
    pile: ()->
        return _ @models
    sorted: (playToWin=true)->
        return @pile().sortByOrder(
            ['suit', 'value'],
            [true, !playToWin]
        ).value()
    arrange: (trump, asPile=false, visible=false, playToWin=true)->
        cards = @sorted(!playToWin)
        unless trump?
            cardPile = _ cards
            visiblePile = cardPile.filter (c)->
                return c.visible
            if asPile
                if visible
                    return visiblePile
                else
                    return cardPile
            else
                if visible
                    return visiblePile.value()
                else
                    return cards
        if !isValidSuit trump
            throw new Error "Expected trump to be one of (#{THE_SUITS.join(', ')})."
        trumps = _(cards).where({suit: trump}).value()
        nonTrumps = _(cards).filter((card)->
            return card.suit isnt trump
        ).value()
        sorted = trumps.concat nonTrumps
        if asPile
            return _ sorted
        return sorted

    has: (card)->
        unless card?.getId?()?
            throw new Error "Expected to be given a card."
        has = @get card.getId()
        return has?

    hasSuit: (suit)->
        unless isValidSuit suit
            throw new Error "Expected to be given a valid suit."
        list = @pile().where({suit: suit}).value()
        return list.length > 0

    probability: (givenCards, reduce=true, cast='string', invert=false)->
        if givenCards instanceof Card
            debug "received Card"
            givenCards = [givenCards] # box as array
        else if (givenCards instanceof CardCollection) and (givenCards?.models?)
            debug "received CardCollection"
            givenCards = givenCards.models # assign as array
        if !_.isArray givenCards
            debug "received Array"
            throw new TypeError "Expected the givenCards to be either a Card, CardCollection, or an array of Cards."
        # if 0 is _.size givenCards
        #     console.log "givenCards aren't anything we recognize", arguments
        #     throw new Error "Probability that you've given bad data: 100%"
        givenIds = _.pluck givenCards, 'id'
        pileRef = @pile
        if _.isFunction pileRef
            pileRef = pileRef.apply @
        total = pileRef.size()
        possible = pileRef.filter((card)->
            return _.contains givenIds, card.getId()
        ).size()
        # debug "total: %s, possible %s", total, possible
        numerator = possible
        if invert
            numerator = total - possible
        denominator = total
        ratio = numerator / denominator
        unless cast is 'decimal'
            unless reduce
                return numerator+'/'+denominator
            frac = new Fraction ratio
            unless cast is 'fraction'
                return frac.toFraction()
            return frac
        return ratio

    compare: (card1, card2, trump)->
        # debug "comparing %s to %s", card1.readable, card2.readable
        if card1.suit is card2.suit
            if card1.value > card2.value
                return card1
            else
                return card2
        unless isValidSuit trump
            throw new Error "Expected trump to be one of #{THE_SUITS.join('|')}."
        isTrump = (card)->
            if card.suit is trump
                return true
            return false
        if isTrump(card1) and !isTrump(card2)
            return card1
        if !isTrump(card1) and isTrump(card2)
            return card2
        # otherwise, the first card wins
        return card1

    validPlays: (comparisonCard, playToWin=true, visible=false)->
        self = @
        unless comparisonCard instanceof Card
            throw new TypeError "Expected card to be an instance of Card."
        self = @
        cards = @models
        hasSuit = @hasSuit comparisonCard.suit
        if hasSuit
            cards = @suit(comparisonCard.suit, false, visible)
        cards = _(cards).sortByOrder(
            ['suit', 'value'],
            [true, !playToWin]
        ).value()
        validCards = cards
        cards = _.filter cards, (card)->
            winner = self.compare comparisonCard, card, comparisonCard.suit
            winnerIsComparison = winner is comparisonCard
            winnerIsGivenCard = !winnerIsComparison
            if playToWin
                if winnerIsGivenCard
                    return true
            else
                if winnerIsComparison
                    return true
            return false
        # if our bid to win results in nothing, use the original cards
        if 0 is _.size cards
            cards = validCards
        return {
            cards: cards
            hasSuit: hasSuit
        }

    hasTrump: (list, trump)->
        if isValidSuit(list) and 1 is _.size arguments
            trump = list
            list = @models
        return _(list).some('suit', trump)

    faceCards: (list, asPile=false, visible=false)->
        if (_.size(arguments) is 1) and _.isBoolean list
            asPile = list
            list = @models
        unless list?
            list = @models
        cards = @arrange(null, true, visible).filter((card)->
            return card.value > 10
        ).value()
        if asPile
            return _ cards
        return cards

    suit: (suit, passPile=true, visible=false)->
        unless isValidSuit suit
            throw new Error "Expected suit to be valid."
        pile = @pile().where({suit: suit})
        if visible? and visible
            pile = pile.where({visible: visible})
        if passPile
            return pile
        return pile.value()

    lowestToHighest: ()->
        return @pile().sortByOrder(['value'], [true]).value()

    highestToLowest: ()->
        return @pile().sortByOrder(['value'], [false]).value()
