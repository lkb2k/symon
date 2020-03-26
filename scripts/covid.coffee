# Description:
#   Get the latest data from Johns Hopkins
#
numeral = require('numeral')
covid = require('covid19-jh')
flatten = (array) ->
    array.reduce(((x, y) -> if Array.isArray(y) then x.concat(flatten(y)) else x.concat(y)), [])

module.exports = (robot) ->

    robot.respond /covid()-?(19)? update (.*)/i, (msg) ->    
        msg.finish()            
        location = msg.match[3].match(/\w+|("|')(?:[^"'])+("|')/g).map((l) -> l.replace(/['"\\]/g, ''))
        covid.country location, (data) -> 
            charts = data.map (d) ->                 
                [
                    {
                        title:"#{d.name} #{numeral(d.dataPoints[d.dataPoints.length - 1].deaths).format(0,0)} Deaths",
                        image_url:d.chart('deaths') 
                    },
                    {
                        title:"#{d.name} #{numeral(d.dataPoints[d.dataPoints.length - 1].cases).format(0,0)} Cases",
                        image_url:d.chart('cases') 
                    }
                ]
            response =
                attachments: flatten charts
                username: robot.name
                as_user: true

            console.log(response)
            msg.send response if data


