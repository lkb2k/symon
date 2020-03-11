# Description:
#   Get a stock chart
#
token = process.env.HUBOT_IEX_CLOUD_TOKEN || 'NO_IEX_API_KEY'
baseURL = "https://cloud.iexapis.com/stable/stock/"

module.exports = (robot) ->
    
    robot.respond /stock (.*)/i, (msg) ->    
        msg.finish()            
        ticker = msg.match[1].toUpperCase()

        url = "#{baseURL}#{ticker}/time-series?token=#{token}"        
        robot.http(url).get() (err, res, body) ->
            json = JSON.parse(body)
            prices = json.map (day) -> day.close
            dates = json.map (day) -> day.date.substr(5)
            chart = "https://image-charts.com/chart?chtt=#{ticker}&chbh=a&chd=a:#{prices.join()}&chl=#{prices.join('|')}&chxl=0:|#{dates.join('|')}|&chxt=x&chs=999x250&cht=bvg"

            response =
                attachments: [
                    {title:ticker, image_url:chart}
                ]
                username: robot.name
                as_user: true

            console.log(JSON.stringify(response))
            msg.send response


