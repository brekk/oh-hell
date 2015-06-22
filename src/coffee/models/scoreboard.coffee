"use strict"
_ = require 'lodash'
Bacon = require 'baconjs'

Scoreboard = ($bus)->
    mergeIncomingStreams = (first, next)->
        return _.assign first, next
    debug = require('debug') "scoreboard"
    debug "scoreboard initializing..."
    $scorePipe = $bus.ofType('score')
    $trumpPipe = $bus.ofType('trump')
    $betPipe = $bus.ofType('bet')
    $roundStart = $bus.ofType('roundStart')
    $config = $bus.ofType('config')
    $betPipe.merge $roundStart
            .merge $trumpPipe
            .merge $config
            .scan {}, mergeIncomingStreams
            .changes()
            .onValue ($event)->
                if $event.bets? and $event.trump? and $event.bet? and $event.roundStart? and $event.config?
                    totalPlayers = $event.playerSort(0).length
                    bets = $event.bets
                    debug "totalPlayers", totalPlayers
                    betsRemain = (bets.length + 1 <= totalPlayers)
                    activePlayer = _.first $event.playerSort $event.playerIndex
                    nextPlayerIndex = $event.playerIndex + 1
                    nextPlayer = _.first $event.playerSort nextPlayerIndex
                    sendInfo = (role)->
                        return {
                            message: "turn"
                            role: role
                            turn: nextPlayer.name
                            bets: $event.bets
                            playerIndex: $event.playerIndex + 1
                        }
                    validBets = ()->
                        theBetting = _.sum($event.bets)
                        x = $event.config.activeCardsThisHand
                        if theBetting is 0
                            return [0..x]
                        return _.without [0..x], x - theBetting
                    isValidBet = (x)->
                        v = validBets()
                        return _.contains v, x
                    if betsRemain
                        debug "%s / %s", $event.playerIndex, totalPlayers
                        if ($event.playerIndex is totalPlayers and !isValidBet $event.bet)
                            debug "Invalid bet, %s! (%s + %s = %s) Bet again.", activePlayer.name, _.sum($event.bets), $event.bet, $event.config.activeCardsThisHand
                            $bus.plug Bacon.later 10, {
                                message: "turn"
                                role: "bet:again"
                                turn: activePlayer.name
                                playerIndex: $event.playerIndex
                            }
                        else
                            debug "do bets remain? %s", (bets.length + 1 < totalPlayers)
                            $event.bets.push $event.bet
                            debug "betting", bets
                            debug "theBetting: %s", _.sum($event.bets)
                            if bets.length < totalPlayers
                                debug "next player's turn! %s", nextPlayer.name
                                $bus.plug Bacon.later 100, sendInfo 'bet'
                    if bets.length is totalPlayers
                        debug "Everyone has bet!"
                        debug "It's %s's turn to play a card.", nextPlayer.name
                        $bus.plug Bacon.later 100, sendInfo 'play'

module.exports = Scoreboard