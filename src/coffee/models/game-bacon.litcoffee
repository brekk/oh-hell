    ((__config__)->
        "use strict"
        debugMaker = require('debug')
        debugMain = debugMaker 'main'
        debugMain "Sanity check..."

        try
            shiftArray = require './shiftable-array'
        catch e
            shiftArray = require '../utils/shiftable-array.coffee'

# Learning Reactive Programming with Bacon.js

based on https://github.com/raimohanska/worzone/blob/master/worzone.js

        Bacon = require 'baconjs'
        _ = require 'lodash'
        Promise = require 'bluebird'

        THE_SUITS = [
            'clubs'
            'diamonds'
            'hearts'
            'spades'
        ]

        DECK_OWNER = 'DECK'

        compareCards = (card1, card2, trump)->
            # debug "comparing %s to %s", card1.readable, card2.readable
            if card1.suit is card2.suit
                if card1.value > card2.value
                    return card1
                else
                    return card2
            if trump?
                if trump.suit?
                    trump = trump.suit
                unless !_.contains THE_SUITS, trump
                    throw new Error "Expected trump to be one of #{THE_SUITS.join('|')}."
                isTrump = (card)->
                    if card.suit is trump
                        return true
                    return false
                if isTrump(card1) and !isTrump(card2)
                    return card1
                if !isTrump(card1) and isTrump(card2)
                    return card2
            # otherwise, the first card wins
            return card1

        compareAll = (cards, trump)->
            p = new Promise (resolve, reject)->
                done = _.after (cards.length - 1), (theWinner)->
                    console.log "fire!", theWinner.readable
                    resolve theWinner
                winner = _.first cards
                _.each _.rest(cards), (card)->
                    comparison = compareCards(winner, card, trump)
                    # console.log '   ', winner.readable, 'vs.', card.readable, "is", comparison.readable
                    if comparison isnt winner
                        winner = comparison
                    done winner
            return p

        Card = (value, suit)->
            if !_.isNumber(value) or !_.inRange value, 2, 15
                throw new TypeError 'Expected value to be from 2 - 14.'
            if !_.isString(suit) or !_.contains THE_SUITS, suit
                throw new TypeError "Expected suit to be one of #{THE_SUITS.join('|')}"
            card = {
                value: value
                suit: suit
                owner: DECK_OWNER
            }
            card.toString = ()->
                return card.value + ' of ' + card.suit
            card.readable = card.toString()
            card.compare = (c2, trump)->
                return compareCards card, c2, trump
            return card

        Deck = ()->
            debug = debugMaker 'deck'
            cards = _.map THE_SUITS, (suit)->
                debug "generating suit: %s", suit
                return _.map [2..14], (value)->
                    c = new Card value, suit
                    return c
            return _(cards).flatten().shuffle().value()

Let's define the game:

Game > Round :: round-index
Game < Round :: point-winner
Game > Dealer :: assign-dealer

        Game = ($bus)->
            debug = debugMaker 'game'
            debug "generating deck..."
            deck = Deck()
            cardsPerHand = [1..7].reverse().concat [1..7]
            totalHands = 14
            config = _.extend {
                cardsPerHand: cardsPerHand
                totalHands: totalHands
            }, __config__
            if (config.round? and _.isNumber config.round) and (config.round < cardsPerHand.length)
                config.activeCardsThisHand = cardsPerHand[config.round]
                debug "setting activeCardsThisHand: %s", config.activeCardsThisHand
            debug "config", config, cardsPerHand[config.round]
            $bus.push {
                message: 'config'
                config: config
            }
            $bus.push {
                message: 'cards'
                cards: deck
            }

        Scoreboard = ($bus)->
            mergeIncomingStreams = (first, next)->
                return _.assign first, next
            debug = debugMaker "scoreboard"
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


Let's define the round:

Round < Game :: round-index
Round < Trick :: trick-winner
Round > Player :: point-winner

        Round = ($bus)->
            debug = debugMaker 'round'
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


Let's define the basic players:

        Players = ($bus)->
            brekk = Player 'Brekk', true, $bus
            lastRandomName = null
            names = [
                'Jimmy'
                'Betty'
                'Donatello'
                'Raphael'
                'Leonardo'
                'Michaelangelo'
                'Blossom'
                'Bubbles'
                'Buttercup'
                'Meatwad'
                'Frylock'
                'Master Shake'
                'Ignignokt'
                'Err'
                'Carl Brutanadilewski'
            ]
            randomName = ()->
                randomIndex = Math.floor Math.random() * names.length
                lastRandomName = names[randomIndex]
                if lastRandomName?
                    names = _.without names, lastRandomName
                return lastRandomName
                

            _.each [0..2], ()->
                Player randomName(), false, $bus
            ###
            jimmy = Player 'Jimmy', false, $bus
            betty = Player 'Betty', false, $bus
            $bus.push {
                message: 'players'
                players: [brekk, jimmy, betty]
            }
            ###

Let's hook up a dealer:

Dealer < Game :: assign-dealer
Dealer > Trick :: card-trump
Dealer > Player :: card-dealt

        Dealer = ($bus)->
            debug = debugMaker 'dealer'
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


And the definition of a player:

        Player = (name, human=false, $bus)->
            debug = debugMaker name
            player = {
                name: name
                human: human
                bet: null
                cards: null
                toString: ()->
                    return "Player"
                isHuman: ()->
                    return @human
                isRobot: ()->
                    return !@human
            }
            # dunno if this is right yet
            cardsOwnedByPlayer = (card)->
                return card.owner is player.name
            mergeIncomingStreams = (oldStuff, newStuff)->
                return _.extend oldStuff, newStuff
            $bus.ofType('trump')
                .merge($bus.isTurn())
                .merge($bus.ofTypeForPlayer('hand', name))
                .scan({}, mergeIncomingStreams)
                .changes()
                .onValue ($event)->
                    if $event.trump? and $event.cards?
                        if !player.cards?
                            player.cards = $event.cards
                        # debug "trump: %s", $event.trump.readable
                        # debug "hand:", _.pluck $event.cards, 'readable'
                        if $event.role? and $event.turn? and $event.playerIndex? and $event.bets?
                            if $event.turn is name
                                betAgain = false
                                lastBet = null
                                rollBet = ()->
                                    return Math.floor Math.random() * 4 # $event.cards.length
                                if $event.role is 'bet:again' and player.bet?
                                    debug("ensuring no duplicate bets...")
                                    lastBet = player.bet
                                    player.bet = null
                                    betAgain = true
                                    $event.role = 'bet'
                                if $event.role is 'bet' and !player.bet?
                                    bet = rollBet()
                                    reroll = ()->
                                        debug("rerolling...")
                                        bet = rollBet()
                                    reroll() while betAgain and (bet is lastBet)
                                    debug "betting %s", bet
                                    player.bet = bet
                                    $bus.push {
                                        owner: name
                                        player: name
                                        playerObject: player
                                        message: 'bet'
                                        bet: bet
                                        playerIndex: $event.playerIndex
                                        bets: $event.bets
                                    }
                                randomCard = ()->
                                    cards = $event.cards
                                    randomIndex = Math.floor Math.random() * cards.length
                                    return _.shuffle(cards)[randomIndex]
                                if $event.role is 'play'
                                    card = randomCard()
                                    debug "Playing card %s", card.readable
                                    $bus.push {
                                        owner: name
                                        player: name
                                        message: 'play'
                                        card: card
                                        cardsInPlay: if $event.cardsInPlay? then $event.cardsInPlay else []
                                        bets: $event.bets
                                        playerIndex: $event.playerIndex
                                        playerObject: player
                                    }
                                if $event.role is 'play:again' and $event.suit?
                                    card = _($event.cards).where({suit: $event.suit}).first()
                                    debug "Ok, I'll follow suit: %s", card.readable
                                    $bus.push {
                                        owner: name
                                        player: name
                                        message: 'play'
                                        card: card
                                        cardsInPlay: if $event.cardsInPlay? then $event.cardsInPlay else []
                                        bets: $event.bets
                                        playerIndex: $event.playerIndex
                                        playerObject: player
                                    }

            debug "Player created!"
            $bus.push {
                message: 'player'
                player: player
            }
            return player

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
            Game buses.messages

        initialize()

    )({
        round: 1
    })
