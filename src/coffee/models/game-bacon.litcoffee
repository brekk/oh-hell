    ((__config__)->
        "use strict"
        debugMaker = require('debug')
        debugMain = debugMaker 'main'
        debugMain "Sanity check..."

# Learning Reactive Programming with Bacon.js

based on https://github.com/raimohanska/worzone/blob/master/worzone.js

        Bacon = require 'baconjs'
        _ = require 'lodash'

        {THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

        {compareAll, compareCards, Card} = require './card'

Let's define the game:

Game > Round :: round-index
Game < Round :: point-winner
Game > Dealer :: assign-dealer

        Game = require './game'

        Scoreboard = require './scoreboard'


Let's define the round:

Round < Game :: round-index
Round < Trick :: trick-winner
Round > Player :: point-winner

        Round = require './round'

Let's define the basic players:

        Players = require './runtime'

Let's hook up a dealer:

Dealer < Game :: assign-dealer
Dealer > Trick :: card-trump
Dealer > Player :: card-dealt

        Dealer = require './dealer'


And the definition of a player:

        Player = require './player'

# Let's hook together all the messages with a bus


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
        round: 1
    })
