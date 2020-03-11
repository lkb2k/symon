# Description:
#   Get the latest data from Johns Hopkins
#
covid = require('covid19-jh')


module.exports = (robot) ->

    robot.respond /covid update (.*)/i, (msg) ->    
        location = msg.match[1]
        msg.reply 'covid19 in the '+location+'?'
        covid.country location, (data) -> 
            msg.send data.chart() if data
            msg.reply "couldn't find "+location if !data
        msg.finish()            

