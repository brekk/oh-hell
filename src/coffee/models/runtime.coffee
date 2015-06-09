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

        game.on 'player:mistake', (player, suit)->
            unless player.human
                console.log "#{player.name}, you can't play that card, you have to play #{suit}."
                console.log "The machines made a mistake playing the game. Write more tests."
            else
                console.log "#{player.name}, you can't play that card, you have to play #{suit}."

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
                if cardsInPlay.length > 0
                    firstCard = _.first cardsInPlay
                    validPlays = player.hand.validPlays firstCard, strategy.playToWin
                    player.playCard _.first validPlays.cards
                else
                    player.playCard player.hand.arrange(game.trump.suit, false, false, strategy.playToWin)[0]

        # we should add a similar 'bet:player', or "turnToBet:player" ()->

        game.on 'change:allBetsIn', ()->
            console.log "arguments, to allbets in", arguments
            jimmy.playCard jimmy.randomCard()

        game.play()

        module.exports = {
            brekk: brekk
            jimmy: jimmy
            betty: betty
            game: game

        }
    catch e
        console.log "ERROR", e
        if e.stack?
            console.log e.stack
)()