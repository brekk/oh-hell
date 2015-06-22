"use strict"

Model = require 'ampersand-state'
_ = require 'lodash'
Bacon = require 'baconjs'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

try
    shiftArray = require './shiftable-array'
catch e
    shiftArray = require '../utils/shiftable-array.coffee'

module.exports = Dealer = ($bus)->
    debug = require('debug') 'dealer'
    debug "dealer exists"
    ###
    $bus.ofType('players').onValue ($event)->
        players = $event.players
        console.log "players", players
        _.each players, (player)->
            $bus.push {
                message: 'player'
                player: player
            }
    ###
    groupPlayers = (first, next)->
        first.push next
        return first
    dealerIndex = 0
    playerIndex = 1
    activePlayer = null
    playerSort = null
    playerAt = null
    indexForPlayer = null
    announce = (players)->
        if players? and players.length? and players.length > 0
            debug "index of dealer: %s", dealerIndex
            players = _.pluck players, 'player'
            playerAt = (idx)->
                if idx is 0
                    return _.first players
                return _.at players, idx
            dealer = playerAt dealerIndex
            name = _.get dealer, 'name'
            debug "%s is the dealer", name
            activePlayer = _.at players, playerIndex
            playerSort = shiftArray players
            indexForPlayer = (name)->
                out = _(players).map((player, idx)->
                    if player.name is name
                        if idx isnt 0
                            return idx
                        return '*'
                ).compact().first()
                if out is '*'
                    return 0
                return out

    $players = $bus.ofType('player')
                   .scan([], groupPlayers)
                   .debounce(200)
                   .doAction announce
                   .changes()
    $config = $bus.ofType('config')
    mergeIncomingStreams = (first, next)->
        if _.isArray(next) and _.first(next).message is 'player'
            next = {
                players: _.pluck next, 'player'
            }
        return _.assign first, next
    $bus.ofType('cards')
        .merge($players)
        .merge($config)
        .scan({}, mergeIncomingStreams)
        .changes()
        .onValue ($event)->
            if $event.players? and $event.cards? and $event.config? and $event.config.activeCardsThisHand?
                {cards, players, config} = $event
                chunks = _.chunk cards, config.activeCardsThisHand
                trump = _.first chunks[players.length]
                debug "trump! %s", trump.readable
                $bus.push new Bacon.Next {
                    message: "trump"
                    trump: trump
                }
                if _.isFunction playerSort
                    _.each playerSort(dealerIndex + 1), (player, idx)->
                        chunk = _.map chunks[idx], (card)->
                            card.owner = player.name
                            return card
                        debug "dealing hand to player: %s", player.name
                        $bus.push new Bacon.Next {
                            message: "hand"
                            owner: player.name
                            cards: chunk
                        }
                        if idx is 0
                            debug "telling %s to bet", player.name
                            $bus.plug Bacon.later 500, {
                                message: "turn"
                                role: "bet"
                                turn: player.name
                                playerIndex: playerIndex
                                bets: []
                            }
                    $bus.push new Bacon.Next {
                        message: "roundStart"
                        roundStart: true
                        playerSort: playerSort
                        playerAt: playerAt
                        round: config.round
                        dealerIndex: dealerIndex
                        playerIndex: playerIndex
                        indexForPlayer: indexForPlayer
                    }