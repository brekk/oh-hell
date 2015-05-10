# Screw Your Neighbor
## It's a card game

### Basic Architecture

  * Card - It's a card with a suit and a value!
  * Deck - It's the full collection of cards!
  * Trump - It's a special card that changes each hand!
  * Player - It's a player!
  * Hand - It's a collection of cards that a player has.
  * Trick - It's a round of play.
  * Bet - It's the number of tricks a player thinks they will take.
  * Count - It's the total number of cards that were dealt in a hand.

Psuedo Models

    "use strict"
    _ = require 'lodash'
    Model = require 'ampersand-state'
    Collection = require 'ampersand-collection'
    lodashMixin = require 'ampersand-collection-lodash-mixin'
    uuid = require 'random-uuid-v4'

    SUIT_HEARTS = 'hearts'
    SUIT_CLUBS = 'clubs'
    SUIT_DIAMONDS = 'diamonds'
    SUIT_SPADES = 'spades'

    THE_SUITS = [
        SUIT_HEARTS
        SUIT_CLUBS
        SUIT_DIAMONDS
        SUIT_SPADES
    ]

    Card = Model.extend
        idAttribute: 'id'
        props: {
            suit:
                type: 'string'
                values: THE_SUITS
                required: true
            value:
                type: 'number'
                values: [2..14]
                required: true
        }
        session: {
            id:
                required: true
                type: 'string'
                default: ()->
                    return uuid()
        }
        derived: {
            readable:
                deps: [
                    'suit'
                    'value'
                ]
                cache: true
                fn: ()->
                    self = @
                    barf = (v)->
                        return v + ' of ' + self.suit
                    unless @value > 10
                        return barf @value
                    pretty = switch @value
                        when 11 then barf "jack"
                        when 12 then barf "queen"
                        when 13 then barf "king"
                        when 14 then barf "ace"
                    return pretty
        }

    CardCollection = Collection.extend lodashMixin, {
        model: Card
        mainIndex: 'id'
        indexes: ['suit', 'value']
    }

    Deck = Model.extend
        collections:
            hearts: CardCollection
            clubs: CardCollection
            diamonds: CardCollection
            spades: CardCollection
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


        initialize: ()->
            self = @
            _.each THE_SUITS, (suit)->
                # console.log "making suit: ", suit
                twoThroughAce = _.map [2..14], (value)->
                    # console.log "suit value", suit, value
                    card = new Card {
                        suit: suit
                        value: value
                    }
                    return card
                self[suit] = new CardCollection twoThroughAce
            return self




    Hand = CardCollection.extend


    Dealer = Model.extend
        deal: (deck, count)->

    Player = Model.extend
        session:
            bet: ['number', false]
            isDealer: ['boolean', true, false]
            playOrder: ['number', true, 0]
        collections:
            hand: Hand

    module.exports = {
        Deck: Deck
        Card: Card
    }

    
+ Card
* props: 
  - suit: [hearts|clubs|diamonds|spades]
  - value: [2..10|j:11, q:12, k:13, a:14]
+ Deck
* collections:
  - cards: { model: card}
* session:
  - shuffled
+ Player
* session
  - bet: ['number', false]
  - isDealer: ['boolean', true, false]
  - playOrder: ['number', true, 0]
* collections: 
  - hand: {
        model: Card
    }

