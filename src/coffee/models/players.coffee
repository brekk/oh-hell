"use strict"
Player = require './player'
_ = require 'lodash'

Players = ($bus)->
    brekk = Player 'Brekk', true, $bus
    lastRandomName = null
    names = [
        'Jimmy'
        'Betty'
        'Donatello'
        'Raphael'
        'Leonardo'
        'Michaelangelo'
        'Blossom'
        'Bubbles'
        'Buttercup'
        'Meatwad'
        'Frylock'
        'Master Shake'
        'Ignignokt'
        'Err'
        'Carl Brutananadilewski'
    ]
    randomName = ()->
        randomIndex = Math.floor Math.random() * names.length
        lastRandomName = names[randomIndex]
        if lastRandomName?
            names = _.without names, lastRandomName
        return lastRandomName

    _.each [0..2], ()->
        Player randomName(), false, $bus

module.exports = Players