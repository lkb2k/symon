# Description:
#   Get the latest data from Johns Hopkins
#
covid = require('covid19-jh')

module.exports = (robot) ->

    robot.respond /covid()-?(19)? update (.*)/i, (msg) ->    
        msg.finish()            
        location = msg.match[3]
        covid.country location, (data) -> 
            if data
                url = data.chart().replace(/\|/g,'%7C')
                response =
                    attachments: [
                        {title:"#{location} confirmed cases", image_url:url}
                    ]
                    username: robot.name
                    as_user: true

                msg.send response if data
            else
                msg.reply "couldn't find "+location if !data


