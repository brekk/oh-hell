(->
    try
        "use strict"
        _ = require 'lodash'

        Game = require './game'
        Player = require './player'
        
        game = new Game()
        brekk = new Player({
            name: 'Brekk'
        })
        game.addPlayer brekk
        
        jimmy = new Player({name: 'Jimmy'})
        game.addPlayer jimmy

        brekk = game.players.models[0]
        jimmy = game.players.models[1]

        game.dealRound 0
        brekkCards = brekk.hand.arrange(game.trumpSuit, true).pluck('readable').value()
        jimmyCards = jimmy.hand.arrange(game.trumpSuit, true).pluck('readable').value()

        game.on 'change:allBetsIn', ()->
            console.log "all bets in"
            brekk.playCard brekk.hand.models[0]

        console.log "Brekk's cards: ", brekkCards

        brekk.bet _.size brekk.trumps

        console.log "Jimmy's cards: ", jimmyCards

        jimmy.bet _.size jimmy.trumps

        # console.log brekkCards.length, jimmyCards.length

        # console.log "playing through auto shia"
        # _.times brekkCards.length, (cardIndex)->
        #     brekkCard = brekkCards[cardIndex]
        #     jimmyCard = jimmyCards[cardIndex]
        #     console.log "brekk plays", brekkCard.readable
        #     console.log "jimmy plays", jimmyCard.readable
        #     winningCard = game.compare brekkCard, jimmyCard
        #     console.log "winner!", winningCard.owner

        module.exports = {
            brekk: brekk
            jimmy: jimmy
            game: game

        }
    catch e
        console.log "ERROR", e
        if e.stack?
            console.log e.stack
)()