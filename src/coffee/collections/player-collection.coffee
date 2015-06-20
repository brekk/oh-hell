"use strict"
Player = require './player'
Collection = require './base-collection'
_ = require 'lodash'

module.exports = PlayerCollection = Collection.extend
    model: Player
    pluck: (value)->
        return _(@models).map((player)->
            out = {}
            if value? and player[value]?
                out[player.name] = player.tricks
            return out
        ).reduce (collection, iter)->
            return _.extend collection, iter
        , {}
    tricks: ()->
        return @pluck 'tricks'
    points: ()->
        return @pluck 'points'