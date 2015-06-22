    _ = require 'lodash'
    $EVENTS = {
        Game:
            gives:
                dealerAssignment: 
                    event: "assign-dealer"
                    index: 1
            receives:
                player: 
                    event: 'join-player'
                    index: 0
                dealNext: 
                    event: "deal-next-round"
                    index: 11
        Dealer:
            receives:
                assignment: 
                    event: "assign-dealer"
                    index: 2
            gives:
                announceTrump: 
                    event: "announce-trump"
                    index: 3
                cards: 
                    event: "deal-hand"
                    index: 4
        Scoreboard:
            receives:
                trump: 
                    event: "announce-trump"
                    index: 3
                bet: 
                    event: "place-bet"
                    index: 5
                roundEndAnnouncement:
                    event: 'end-round'
                    index: 10
            gives:
                nextRoundRequest: 
                    event: "deal-next-round"
                    index: 11
                startEvent: 
                    event: 'start-round'
                    index: 6
        Round:
            receives:
                startEvent: 
                    event: 'start-round'
                    index: 6
                winnerOfTrick: 
                    event: 'winner-trick'
                    index: 9
            gives:
                endEvent: 
                    event: 'end-round'
                    index: 10
                playerTurn:
                    event: 'player-turn'
                    index: 7
        Trick:
            receives:
                cards: 
                    event: "play-card"
                    index: 8
            gives:
                winner: 
                    event: "winner-trick"
                    index: 9
        Player:
            receives:
                turn:
                    event: 'player-turn'
                    index: 7
                cards: 
                    event: "deal-hand"
                    index: 4
            gives:
                bet: 
                    event: "place-bet"
                    index: 5
                card: 
                    event: "play-card"
                    index: 8
                greeting: 
                    event: "join-player"
                    index: 0
    }
    _.each $EVENTS, (actor, role)->
        _.each $EVENTS, (actor2, role2)->
            if role isnt role2
                actorGivesToActor2 = _(actor.gives).sortBy('index').filter((action)->
                    receivers = _.pluck actor2.receives, 'event'
                    return _.contains receivers, action.event
                ).first()
                actorReceivesFromActor2 = _(actor.receives).sortBy('index').filter((action)->
                    givers = _.pluck actor2.gives, 'event'
                    return _.contains givers, action.event
                ).first()
                x = {}
                y = {}
                if actorGivesToActor2?
                    console.log "#{role} > #{role2} ::", actorGivesToActor2.event
                if actorReceivesFromActor2?
                    console.log "#{role} < #{role2} ::", actorReceivesFromActor2.event

    orderedEvents = _($EVENTS).map((actor, role)->
        list = []
        if actor.receives?
            list = list.concat _.toArray actor.receives
        if actor.gives?
            list = list.concat _.toArray actor.gives
        return list
    ).flatten().sortBy('index').pluck('event').unique().value()

    console.log "EVENTS ============="
    _.each orderedEvents, (event, idx)->
        console.log "#{idx}: #{event}"