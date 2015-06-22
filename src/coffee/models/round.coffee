"use strict"
_ = require 'lodash'
Bacon = require 'baconjs'

{compareAll, compareCards, Card} = require './card'

Round = ($bus)->
    debug = require('debug') 'round'
    debug "round created..."
    $roundStart = $bus.ofType('roundStart')
    $trump = $bus.ofType('trump')
    $playCards = $bus.ofType('play')
    $roundEnd = $bus.ofType('roundStart')
    $config = $bus.ofType('config')
    mergeIncomingStreams = (first, next)->
        return _.assign first, next
    mergedValueListener = ($event)->
        if $event?.config?.round?
            debug "round begun: %s", $event.config.round
    playCardsListener = ($event)->
        card = _.get $event, 'card'
        config = _.get $event, 'config'
        trump = _.get $event, 'trump'
        player = _.get $event, 'playerObject'
        if card? and config? and trump? and player?
            debug "card attempting to be played: %s", card.readable
            totalPlayers = _.size $event.playerSort(0)
            if $event.cardsInPlay? and _.isArray $event.cardsInPlay
                firstCard = _.first $event.cardsInPlay
                if (firstCard?.suit?) and (card.suit isnt firstCard.suit) and (_.contains _.pluck(player.cards, 'suit'), firstCard.suit)
                    debug "%s, you have to follow suit, and you have %s in your hand.", player.name, firstCard.suit
                    $bus.plug Bacon.later 100, {
                        message: "turn"
                        role: "play:again"
                        turn: player.name
                        bets: $event.bets
                        playerIndex: $event.playerIndex
                        suit: firstCard.suit
                    }
                    return
                else
                    $event.cardsInPlay.push card
                    if _.size($event.cardsInPlay) is totalPlayers
                        happy = (card)->
                            debug "%s is the winner!", card.owner
                        sad = (e)->
                            console.log "error", e
                            if e.stack?
                                console.log e.stack
                        compareAll($event.cardsInPlay).then happy, sad

                        return
                    else
                        debug "cards in play: ", _.pluck $event.cardsInPlay, 'readable'
                        nextPlayerIndex = $event.playerIndex + 1
                        nextPlayer = _.first $event.playerSort(nextPlayerIndex)
                        debug "telling next player (%s) to play card!", nextPlayer.name
                        $bus.plug Bacon.later 100, {
                            message: "turn"
                            role: "play"
                            turn: nextPlayer.name
                            playerIndex: nextPlayerIndex
                            bets: $event.bets
                            cardsInPlay: $event.cardsInPlay
                        }
                        return
    $playCards.merge($roundStart)
              .merge($trump)
              .merge($config)
              .scan({}, mergeIncomingStreams)
              .onValue playCardsListener
    $roundStart.merge($config)
               .scan({}, mergeIncomingStreams)
               .onValue mergedValueListener

module.exports = Round