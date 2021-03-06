"use strict"
_ = require 'lodash'
debug = require('debug') 'oh-hell:card'
Model = require 'ampersand-state'
uuid = require 'random-uuid-v4'
_ = require 'lodash'

{THE_SUITS, DECK_OWNER, isValidSuit} = require './environment'

module.exports = Card = Model.extend
    idAttribute: 'id'
    props: {
        suit:
            type: 'string'
            values: THE_SUITS
            required: true
        value:
            type: 'number'
            values: [2..14]
            required: true
        owner:
            type: 'string'
            required: true
            default: ()->
                return DECK_OWNER
    }
    session: {
        id:
            required: true
            type: 'string'
            default: ()->
                return uuid()
        visible: ['boolean', true, false]
    }
    derived: {
        readable:
            deps: [
                'suit'
                'value'
            ]
            cache: true
            fn: ()->
                self = @
                barf = (v)->
                    return v + ' of ' + self.suit
                unless @value > 10
                    return barf @value
                pretty = switch @value
                    when 11 then barf "jack"
                    when 12 then barf "queen"
                    when 13 then barf "king"
                    when 14 then barf "ace"
                return pretty
    }