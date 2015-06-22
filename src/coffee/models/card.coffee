"use strict"
_ = require 'lodash'
Promise = require 'bluebird'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

compareCards = (card1, card2, trump)->
    # debug "comparing %s to %s", card1.readable, card2.readable
    if card1.suit is card2.suit
        if card1.value > card2.value
            return card1
        else
            return card2
    if trump?
        if trump.suit?
            trump = trump.suit
        unless !_.contains THE_SUITS, trump
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

compareAll = (cards, trump)->
    p = new Promise (resolve, reject)->
        done = _.after (cards.length - 1), (theWinner)->
            resolve theWinner
        winner = _.first cards
        _.each _.rest(cards), (card)->
            comparison = compareCards(winner, card, trump)
            if comparison isnt winner
                winner = comparison
            done winner
    return p

Card = (value, suit)->
    if !_.isNumber(value) or !_.inRange value, 2, 15
        throw new TypeError 'Expected value to be from 2 - 14.'
    if !_.isString(suit) or !_.contains THE_SUITS, suit
        throw new TypeError "Expected suit to be one of #{THE_SUITS.join('|')}"
    card = {
        value: value
        suit: suit
        owner: DECK_OWNER
    }
    card.toString = ()->
        return card.value + ' of ' + card.suit
    card.readable = card.toString()
    card.compare = (c2, trump)->
        return compareCards card, c2, trump
    card.isOver = (value)->
        return @value > value
    card.isUnder = (value)->
        return @value < value
    return card

module.exports = {
    Card: Card
    compareAll: compareAll
    compareCards: compareCards
}