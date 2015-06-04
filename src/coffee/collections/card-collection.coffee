"use strict"

_ = require 'lodash'
Collection = require './base-collection'
Card = require './card'

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

    probability: (card, givenVisibleCards, invert=false)->
        unless givenVisibleCards?
            givenVisibleCards = @models
        if givenVisibleCards.models?
            givenVisibleCards = givenVisibleCards.models
        if 0 is _.size givenVisibleCards
            throw new Error "Probability that you've given bad data: 100%"
        givenVisibleCardIds = _.map givenVisibleCards, (card)->
            return card.getId()
        possible = @pile.filter((card)->
            return !_.contains givenVisibleCardIds, card.getId()
        ).size() + 1
        total  = @pile.size()
        ratio = possible / total
        unless invert
            return ratio
        return (total - possible) / total

    compare: (card1, card2, trump)->
        debug "comparing %s to %s", card1.readable, card2.readable
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
            debug " --> ", card1.readable
            return card1
        if !isTrump(card1) and isTrump(card2)
            debug " --> ", card2.readable
            return card2
        # otherwise, the first card wins
        debug " --> ", card1.readable
        return card1

    validPlays: (comparisonCard, playToWin=true, visible=false)->
        unless comparisonCard instanceof Card
            throw new TypeError "Expected card to be an instance of Card."
        self = @
        cards = @models
        hasSuit = @hasSuit comparisonCard.suit
        if hasSuit
            cards = @suit(comparisonCard.suit, false, visible)
            console.log "filtered to suit", comparisonCard.suit
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

    cardAgainst: (played, trump, useSuit, visible=false, playToWin=true)->
        self = @
        if played.models?
            played = played.models
        if isValidSuit(trump) and _.isBoolean useSuit
            visible = useSuit
            useSuit = trump
        listPile = null
        # figure out the best of the current collection, given a comparison list, `played`
        if isValidSuit(trump)
            listPile = @arrange(trump, true, visible, playToWin)
        # if we have a useSuit, we should filter for that specific suit
        if isValidSuit(useSuit)
            validSuitPile = listPile.filter (c)->
                return c.suit is useSuit
        if 0 < _.size validSuitPile
            listPile = validSuitPile
        return listPile.value()
        #     comparison = self.compare(playedCard, _.first listPile)
        #     if playToWin
        #         return comparison.getId() isnt playedCard.getId()
        #     else
        #         return comparison.getId() is playedCard.getId()

    suit: (suit, passPile=true, visible=false)->
        unless isValidSuit suit
            throw new Error "Expected suit to be valid."
        pile = @pile().where({suit: suit})
        if visible? and visible
            pile = pile.where({visible: visible})
        if passPile
            return pile
        return pile.value()
