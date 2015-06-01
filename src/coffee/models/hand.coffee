"use strict"
CardCollection = require './card-collection'

module.exports = Hand = CardCollection.extend
    addCard: (card)->
        card.owner = @parent.getId()
        @add card
        return @