"use strict"
_ = require 'lodash'
must = require 'must'
Deck = require '../lib/deck'
deck = new Deck()

describeSuit = (suit)->
    describe '.' + suit, ()->
        it "must be a sub-collection of cards which have suit (#{suit}) and a value between 2 - 14", ()->
            deck[suit].must.be.truthy
            _.size(deck[suit].models).must.equal 13
            _(deck[suit].models).pluck('suit').first().must.equal suit

roundToE8 = (num)->
    return Math.round(num / 1e8) * 1e8

describe "Deck", ()->
    describeSuit 'clubs'
    describeSuit 'diamonds'
    describeSuit 'hearts'
    describeSuit 'spades'
    describe '.cards', ()->
        it "must be the primary collection of cards which are 52 in total, and include cards of all suits", ()->
            # -54 (with jokers)
            _.size(deck.cards.models).must.equal 52
            _([0..10]).each (idx)->
                THE_SUITS.must.include _(deck.cards.models).shuffle().value()[idx].suit
    describe '.probability()', ()->
        it "must be a function which returns the probability of a given card, and when omitted, should use the deck as the default value", ()->
            value = deck.probability deck.pile.shuffle().first()
            value.must.equal 1 / 52
        it "must be a function which returns the probability of a given card within a list of cards", ()->
            value = deck.probability deck.pile.shuffle().first(), deck.cards.models
            value.must.equal 1 / 52
            _.times 10, ()->
                divisor = 1 + Math.round Math.random() * 51
                sliced = deck.cards.models.slice 0, divisor
                value2 = deck.probability deck.pile.shuffle().first(), sliced
                roundToE8(value2).must.equal roundToE8 1 / divisor
        it "must return the inverse ratio when given an optional third parameter", ()->
            value = deck.probability deck.pile.shuffle().first(), deck.cards.models, true
            value.must.equal 51 / 52
            _.times 10, ()->
                divisor = 1 + Math.round Math.random() * 51
                sliced = deck.cards.models.slice 0, divisor
                value2 = deck.probability deck.pile.shuffle().first(), sliced
                roundToE8(value2).must.equal roundToE8 (52 - 1) / divisor


