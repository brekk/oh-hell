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

        game.on 'bet:again', _.throttle (player, sum)->
            unless player.human
                console.log "auto betting #{game.cardsThisRound} for #{player.name}"
                valid = game.validBets()
                randomBet = valid[Math.floor(Math.random() * valid.length)]
                player.bet randomBet
                return
            else
                console.log "#{player.name}, you can't bet that. Bet again."
                return
        , 1000

        game.on 'player:mistake', (player, suit)->
            unless player.human
                console.log "#{player.name}, you can't play that card, you have to play #{suit}."
                console.log "The machines made a mistake playing the game. Write more tests."
            else
                console.log "#{player.name}, you can't play that card, you have to play #{suit}."
            return

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
                console.log "$THE BETTING: #{npc.name}:", game.betting, game.theBetting, strategy
                npc.bet strategy.bet
            return

        game.on 'turn:player', (player, cardsInPlay, trump)->
            unless player.human
                console.log "============= auto-playing for #{player.name}!"
                console.log "              tricks: #{player.tricks} bet: #{player.activeBet}"
                console.log "              trump: #{game.trump.readable}"
                console.log "              cardsInPlay: ", _.pluck cardsInPlay, 'readable'
                strategy = player.strategyToBet()
                if cardsInPlay.length > 0
                    if player.overBid()
                        console.log "#{player.name} is over their bid, so they will now try to take as many tricks as possible."
                        strategy.playToWin = true
                    if player.activeBet is player.tricks
                        console.log "#{player.name} is at their bid, so they will try to slough off."
                        strategy.playToWin = false
                    firstCard = _.first cardsInPlay
                    validPlays = player.hand.validPlays firstCard, strategy.playToWin
                    card = _.first validPlays.cards
                    if card?
                        player.play card
                    else
                        player.play player.randomCard()
                else
                    player.play player.hand.arrange(game.trump.suit, false, false, strategy.playToWin)[0]
            else
                console.log "#{player.name}, it's your turn."
            return

        # we should add a similar 'bet:player', or "turnToBet:player" ()->

        game.on 'change:allBetsIn', ($game, running)->
            if running
                player = game.activePlayer
                console.log "all bets in, #{player.name} to play first card"
                if player isnt brekk
                    randomCard = player.randomCard()
                    if randomCard?.readable?
                        console.log "randoCard", randomCard.readable
                        player.play randomCard
                    else
                        throw new Error 'something is broken with randomCards'
            return

        game.play()

        releaseObject = {
            brekk: brekk
            game: game
            jimmy: jimmy
            betty: betty
            commands: {
                what: ()->
                    if game.betting.length is game.players.length
                        return releaseObject.commands.play()
                    return releaseObject.commands.bet()
                bet: ()->
                    console.log "$THE BETTING:", game.betting, game.theBetting, brekk.strategyToBet()
                    return
                play: ()->
                    console.log "$READABLE", brekk.hand.readable()
                    console.log ">>", brekk.tricks, "tricks (", brekk.activeBet, "bet)"
                    console.log game.trump.readable, "<< trump", game.tricks()
                    _.each game.cardsInPlay, (card, idx)->
                        console.log idx + "..."
                        console.log "   ", card.readable
                        console.log "   ", card.owner
                        console.log "   ", card.visible
                        return
                    return
            }
        }

        module.exports = releaseObject
    catch e
        console.log "ERROR", e
        if e.stack?
            console.log e.stack
)()