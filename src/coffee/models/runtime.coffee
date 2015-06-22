((__config__)->
    "use strict"
    debugMaker = require('debug')
    debugMain = debugMaker 'main'
    debugMain "Sanity check..."

    Bacon = require 'baconjs'
    _ = require 'lodash'

    {THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

    {compareAll, compareCards, Card} = require './card'

    Game = require './game'

    Scoreboard = require './scoreboard'

    Round = require './round'

    Players = require './players'

    Dealer = require './dealer'

    Player = require './player'

    initialize = ()->
        debugMain "initializing..."
        BLT = (forPlayer=false)->
            sandwich = new Bacon.Bus()
            # We can use this to add a simple filter to the messages:
            sandwich.ofType = (type)->
                return sandwich.filter (msg)->
                    return msg.message is type
            sandwich.isTurn = (withRole=null)->
                return sandwich.filter (msg)->
                    messageMatches = msg.message is 'turn'
                    if messageMatches
                        if withRole?
                            return msg.role is withRole
                        return true
                    return false
            if forPlayer
                sandwich.forPlayer = sandwich.fromPlayer = (player)->
                    return sandwich.filter (msg)->
                        if msg?.owner?
                            return msg.owner is player
                        return false
                sandwich.ofTypeForPlayer = (type, player)->
                    return sandwich.filter (msg)->
                        messageMatches = msg.message is type
                        if msg?.owner?
                            return (msg.owner is player) and messageMatches
                        return false
            return sandwich
        debugMain "generating buses..."
        buses = {
            messages: BLT true
            # players: BLT true
        }
        debugMain "beginning round"
        Round buses.messages
        debugMain "establishing scoreboard..."
        Scoreboard buses.messages
        debugMain "assigning dealer..."
        Dealer buses.messages
        debugMain "generating players..."
        Players buses.messages
        debugMain "generating game..."
        Game __config__, buses.messages

    initialize()

)({
    round: 0
})
