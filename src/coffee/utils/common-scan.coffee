"use strict"
_ = require 'lodash'

module.exports = omniscan = (pre, main, post)->
    return (first, next)->
        if _.isFunction pre
            {first, next} = pre first, next
        if _.isFunction main
            {outcome} = main first, next
        if _.isFunction post
            {outcome} = post first, next, outcome
        return outcome