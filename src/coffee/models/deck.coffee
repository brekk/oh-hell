"use strict"
_ = require 'lodash'
Model = require 'ampersand-state'
debug = require('debug') 'oh-hell:deck'
CardCollection = require './card-collection'
Card = require './card'

debug = require('debug') 'oh-hell:deck'

{THE_VALUES, THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

module.exports = Deck = Model.extend
    collections:
        hearts: CardCollection
        clubs: CardCollection
        diamonds: CardCollection
        spades: CardCollection
        hands: CardCollection
    derived:
        cards:
            deps: THE_SUITS
            cache: true
            fn: ()->
                cards = new CardCollection()
                # console.log cards, "<"
                cards.add @hearts.models
                # console.log cards, "< HEARTS"
                cards.add @clubs.models
                # console.log cards, "< CLUBS"
                cards.add @diamonds.models
                # console.log cards, "< DIAMONDS"
                cards.add @spades.models
                # console.log cards, "< SPADES"

                return cards
        pile:
            deps: ['cards']
            cache: true
            fn: ()->
                return _ @cards.models

        shuffledPile:
            deps: ['cards']
            cache: false
            fn: ()->
                return _(@cards.models).shuffle().value()


    initialize: ()->
        self = @
        _.each THE_SUITS, (suit)->
            # console.log "making suit: ", suit
            twoThroughAce = _.map THE_VALUES, (value)->
                # console.log "suit value", suit, value
                card = new Card {
                    suit: suit
                    value: value
                    owner: DECK_OWNER
                }
                return card
            self[suit] = new CardCollection twoThroughAce
        return self

    probability: (card, givenVisibleCards, invert=false)->
        unless givenVisibleCards?
            givenVisibleCards = @cards
        CardCollection::probability.call @, card, givenVisibleCards, invert
        