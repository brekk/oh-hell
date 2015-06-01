"use strict"
_ = require 'lodash'
must = require 'must'
Deck = require '../lib/deck'
deck = new Deck()

{THE_VALUES, THE_SUITS, DECK_OWNER, isValidSuit} = require '../lib/environment'

randoCard = ()->
    return deck.pile.shuffle().first()

describe "Card", ()->
    describe ".suit", ()->
        it "must be a property which is one of (diamonds|spades|hearts|clubs)", ()->
            card = randoCard()
            card.must.have.property 'suit'
            THE_SUITS.must.include card.suit
    describe ".value", ()->
        it "must be a property which is between 2 and 14", ()->
            card = randoCard()
            card.must.have.property 'value'
            THE_VALUES.must.include card.value
    describe ".owner", ()->
        it "must be a property which defaults to \"DECK\"", ()->
            card = randoCard()
            card.must.have.property 'owner'
            card.owner.must.equal DECK_OWNER
    describe ".id", ()->
        it "must be a property which is a unique identifier", ()->
            card = randoCard()
            card.must.have.property 'id'
            card.getId().must.equal card.id