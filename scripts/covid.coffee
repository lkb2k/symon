# Description:
#   Get the latest data from Johns Hopkins
#
covid = require('covid19-jh')
stream = require('stream')

module.exports = (robot) ->

    robot.respond /covid()-?(19)? update (.*)/i, (msg) ->    
        location = msg.match[3]
        covid.country location, (data) -> 
            msg.send data.chart() if data
            robot.http(data.chart())
                .get() (err, res, body) ->
                    robot.adapter.client.web.files.upload(location+".png", {
                        file:stream.Readable.from(body),
                        channels: msg.message.room,
                        filetype:'png'
                    })
            msg.reply "couldn't find "+location if !data
        msg.finish()            

