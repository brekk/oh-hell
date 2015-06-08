(->
    try
        "use strict"
        _ = require 'lodash'
        debug = require('debug') 'oh-hell:runtime'

        Game = require './game'
        Player = require './player'
        
        game = new Game()
        brekk = new Player
            name: 'Brekk'
            human: true
        game.addPlayer brekk
        
        jimmy = new Player name: 'Jimmy'
        game.addPlayer jimmy

        betty = new Player name: 'Betty'
        game.addPlayer betty

        game.on 'bet:again', (player, sum)->
            unless player.human
                console.log "auto betting 7 for #{player.name}"
                player.bet 7
            else
                console.log "#{player.name}, you can't bet that. Bet again."

        game.on 'cards:dealt', (dealtCards)->
            console.log "we will accept betting now"
            _(dealtCards).groupBy('owner').map((group, owner)->
                return console.log owner, ": ", _.pluck(group, 'readable')
            ).value()
            console.log "----- auto betting for non-humans"
            npcs = game.players.where({human: false})
            _.each npcs, (npc)->
                bet = 0
                possibleBets = game.validBets()
                strategy = npc.strategyToBet()
                npc.bet strategy.bet

        game.on 'turn:player', (player, cardsInPlay, trump)->
            unless player.human
                console.log "============= auto-playing for #{player.name}!"
                strategy = player.strategyToBet()
                if suit?
                    validPlays = player.hand.validPlays
                    player.playCard _.first(validPlays, strategy.playToWin).cards

        # we should add a similar 'bet:player', or "turnToBet:player" ()->

        game.on 'change:allBetsIn', ()->
            console.log "arguments, to allbets in", arguments
            jimmy.playCard jimmy.randomCard()

        game.play()

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