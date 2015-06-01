"use strict"
_ = require 'lodash'
must = require 'must'
Game = require '../lib/game'
Player = require '../lib/player'
game = null

{THE_VALUES, THE_SUITS, DECK_OWNER, isValidSuit} = require '../lib/environment'

randoName = ()->
    chunker = Math.round Math.random() * 5
    return _('abcdefghijklmnopqrstuvwxyz'.split('')).shuffle().chunk(chunker).shuffle().value().slice(3, 4)[0].join('')

doubleName = ()->
    return _([0..2]).map(()->
        return randoName()
    ).value().join '-'

addSomePlayers = (totes)->
    return _([0..totes]).map(()->
        return new Player {
            name: doubleName()
        }
    ).value()

describe "Game", ()->
    beforeEach ()->
        game = new Game()
    # methods
    describe ".addPlayer()", ()->
        it "must add a player to the .players collection", ()->
            name = "player" + Math.round Math.random() * 100
            p = new Player {name: name}
            game.addPlayer p
            game.players.models.must.include p
    describe ".dealRound()", ()->
        it "must deal a given number of cards to all players", (done)->
            totes = 1 + Math.round Math.random() * 6
            playersToAdd = addSomePlayers totes
            game.deck.pile.pluck('owner').shuffle().first().must.equal DECK_OWNER
            _.each playersToAdd, (player)->
                game.addPlayer player
            roundIndex = 1 + Math.floor Math.random() * 7
            game.dealRound roundIndex
            groupedPile = game.deck.pile.filter((card)->
                return card.owner isnt DECK_OWNER
            ).groupBy('owner').value()
            _.each groupedPile, (pile)->
                _.size(pile).must.equal game.cardsPerHand[roundIndex]
            nonDeck = game.deck.pile.filter((card)->
                return card.owner isnt DECK_OWNER
            ).value()
            _.size(nonDeck).must.equal (game.players.models.length * game.cardsPerHand[roundIndex])
            countPlayers = _.size(playersToAdd)
            console.log 'countPlayers', countPlayers
            finish = _.after countPlayers + 1, done
            game.on 'change:allBetsIn', ()->
                console.log "fire fire fire", countPlayers
                finish()
            game.on 'change:theBetting', (model, value)->
                console.log "voted", value
                finish()
            game.players.each (player)->
                bet = Math.round Math.random() * game.cardsThisRound
                console.log "player.name", player.name, bet
                player.bet bet