module.exports = (array)->
    return (idx)->
        # [a,b,c,d,e]
        #  0 is default
        #  1 is [b,c,d,e,a]
        idx = idx % array.length
        if idx is 0
            return array
        start = array.slice(0, idx)
        end = array.slice idx
        return end.concat start