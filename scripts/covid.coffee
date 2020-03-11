# Description:
#   Get the latest data from Johns Hopkins
#
covid = require('covid19-jh')

module.exports = (robot) ->

    robot.respond /covid()-?(19)? update (.*)/i, (msg) ->    
        location = msg.match[3]
        covid.country location, (data) -> 
            msg.send "OK <#{data.chart()}|#{location} confirmed cases>" if data
            msg.reply "couldn't find "+location if !data
        msg.finish()            

