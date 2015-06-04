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

        game.on 'cards:dealt', (dealtCards)->
            console.log "we will accept betting now", _(dealtCards).groupBy('owner').map((group)-> return _.pluck(group, 'readable')).value()
            console.log "----- auto betting for jimmy"
            jimmy.bet jimmy.trumps.length

        game.on 'turn:player', (player, suit)->
            if player is jimmy
                console.log "============= auto-playing for jimmy!"
                unless suit?
                    suit = null
                card = jimmy.randomCard(false, suit)
                jimmy.playCard card
                console.log "JIMMY SAYS: ", card.readable

        game.on 'change:allBetsIn', ()->
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