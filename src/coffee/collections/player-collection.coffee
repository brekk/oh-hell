"use strict"
Player = require './player'
Collection = require './base-collection'

module.exports = PlayerCollection = Collection.extend
    model: Player