_ = require 'lodash'

StatusEvent = (message, domain=null, content=null)->
    "use strict"
    unless content?
        content = {}
    output = {
        message: message
        content: content
    }
    if domain?
        output.domain = domain
    return output

StatusEvent.commonScanMain = (first, next)->
    return {outcome: _.extend first, next}

module.exports = StatusEvent