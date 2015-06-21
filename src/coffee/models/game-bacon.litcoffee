    (->
        "use strict"

# Learning Reactive Programming with Bacon.js

based on https://github.com/raimohanska/worzone/blob/master/worzone.js

        Bacon = require 'baconjs'
        _ = require 'lodash'

        $EVENTS = {
            Game:
                gives:
                    dealer: 'assign-dealer'
                    roundIndex: 'round-index'
                receives:
                    winner: 'point-winner'
            Round:
                receives:
                    index: 'round-index'
                    trick: 'trick-winner'
                gives:
                    point: 'point-winner'
            Dealer:
                receives:
                    assignment: 'assign-dealer'
                gives:
                    card: 'card-dealt'
                    trump: 'card-trump'
            Trick:
                receives:
                    trump: 'card-trump'
                    card: 'player-card'
                gives:
                    winner: 'trick-winner'
                    card: 'card-discard'
            Player:
                receives:
                    card: 'card-dealt'
                    turn: 'player-turn'
                    point: 'point-winner'
                gives:
                    card: 'player-card'
                    bet: 'player-bet'
            Board:
                receives:
                    point: 'point-winner'
            Deck:
                receives:
                    card: 'card-discard'
        }
        _.each $EVENTS, (actor, role)->
            _.each $EVENTS, (actor2, role2)->
                if role isnt role2
                    actorGivesToActor2 = _.filter actor.gives, (event)->
                        return _.contains actor2.receives, event
                    actorReceivesFromActor2 = _.filter actor.receives, (event)->
                        return _.contains actor2.gives, event
                    if actorGivesToActor2.length > 0
                        console.log "#{role} > #{role2} ::", actorGivesToActor2.join '|'
                    if actorReceivesFromActor2.length > 0
                        console.log "#{role} < #{role2} ::", actorReceivesFromActor2.join '|'

        THE_SUITS = [
            'clubs'
            'diamonds'
            'hearts'
            'spades'
        ]

        DECK_OWNER = 'DECK'

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
            return card

        Deck = ()->
            cards = _.map THE_SUITS, (suit)->
                return _.map [2..14], (value)->
                    return new Card value, suit
            return _(cards).flatten().shuffle().value()

Let's define the game:

Game > Round :: round-index
Game < Round :: point-winner
Game > Dealer :: assign-dealer

        Game = ($bus)->
            deck = Deck()
            $cards = Bacon.constant {
                message: 'cards'
                cards: deck
            }
            $bus.plug $cards

Let's define the round:

Round < Game :: round-index
Round < Trick :: trick-winner
Round > Player :: point-winner

        Round = (index, $bus)->


Let's define the basic players:

        Players = ($bus)->
            brekk = Player 'Brekk', true, $bus
            jimmy = Player 'Jimmy', false, $bus
            betty = Player 'Betty', false, $bus
            $bus.push {
                message: 'players'
                players: [brekk, jimmy, betty]
            }

Let's hook up a dealer:

Dealer < Game :: assign-dealer
Dealer > Trick :: card-trump
Dealer > Player :: card-dealt

        Dealer = ($bus)->
            $bus.ofType('players').onValue ($event)->
                players = $event.players
                console.log "players", players
                _.each players, (player)->
                    $bus.push {
                        message: 'player'
                        player: player
                    }
            

            $bus.ofType('cards').subscribe ($event)->
                console.log arguments, "args"
                console.log "methods $event", _.methods $event
                console.log "keys $event", _.keys $event
                # console.log "-->", _.chunk $event.valueInternal.cards, 7
                if $event.isInitial()
                    console.log "nexto bacon"
                    $bus.push new Bacon.Next {
                        message: 'hand'
                        cards: _.chunk($event.valueInternal.cards, 7)
                    }
                    return
                # _(cx).chunk(7).map (chunk)->
                #     return _.map chunk, (x)->
                #         x.owner = ''
                


And the definition of a player:

        Player = (name, human=false, $bus)->
            $player = {
                name: name
                human: human
                toString: ()->
                    return "Player"
                isHuman: ()->
                    return @human
                isRobot: ()->
                    return !@human
            }
            # dunno if this is right yet
            cardsOwnedByPlayer = (card)->
                return card.owner is $player.name
            $bus.ofType('hand').subscribe (cards)->
                console.log "player received something", cards
            $cards = $bus.ofType('card')
                         .filter cardsOwnedByPlayer
            $bus.plug $cards
            return $player

# Let's hook together all the messages with a bus

        initialize = ()->
            $eventQueue = new Bacon.Bus()
            # We can use this to add a simple filter to the messages:
            $eventQueue.ofType = (type)->
                return $eventQueue.filter (msg)->
                    return msg.message is type
            Dealer $eventQueue
            Players $eventQueue
            Game $eventQueue

        initialize()

    )()
