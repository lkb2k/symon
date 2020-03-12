# Description:
#   Get the latest data from Johns Hopkins
#
numeral = require('numeral')
covid = require('covid19-jh')

module.exports = (robot) ->

    robot.respond /covid()-?(19)? update (.*)/i, (msg) ->    
        msg.finish()            
        location = msg.match[3].match(/\w+|("|')(?:[^"'])+("|')/g).map((l) -> l.replace(/['"\\]/g, ''))
        console.log(location)
        covid.country location, (data) -> 
            charts = data.map (d) ->                 
                title:"#{d.country} #{numeral(d.dates[d.dates.length - 1].count).format(0,0)}"
                image_url:d.chart()

            response =
                attachments: charts
                username: robot.name
                as_user: true

            console.log(response)
            msg.send response if data


