# Screw Your Neighbor
## It's a card game

### Basic Architecture

  * Card - It's a card with a suit and a value!
  * Deck - It's the full collection of cards!
  * Trump - It's a special card that changes each hand!
  * Player - It's a player!
  * Hand - It's a collection of cards that a player has.
  * Trick - It's a round of play.
  * Bet - It's the number of tricks a player thinks they will take.
  * Count - It's the total number of cards that were dealt in a hand.

Psuedo Models

    "use strict"
    _ = require 'lodash'
    debug = require('debug') 'oh-hell'

    {THE_SUITS, DECK_OWNER, isValidSuit} = require './lib/environment'

    Card = require './lib/card'

    CardCollection = require './lib/card-collection'

    Deck = require './lib/deck'

    Hand = require './lib/hand'

    Dealer = require './lib/dealer'

    Player = require './lib/player'

    Game = require './lib/game'

    module.exports = {
        Deck: Deck
        Card: Card
        Player: Player
        Game: Game
    }

    
+ Card
* props: 
  - suit: [hearts|clubs|diamonds|spades]
  - value: [2..10|j:11, q:12, k:13, a:14]
+ Deck
* collections:
  - cards: { model: card}
* session:
  - shuffled
+ Player
* session
  - bet: ['number', false]
  - isDealer: ['boolean', true, false]
  - playOrder: ['number', true, 0]
* collections: 
  - hand: {
        model: Card
    }

