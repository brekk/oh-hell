"use strict"
CardCollection = require './card-collection'

module.exports = Hand = CardCollection.extend
    addCard: (card)->
        card.owner = @parent.getId()
        card.ownerObject = @parent
        @add card
        return @