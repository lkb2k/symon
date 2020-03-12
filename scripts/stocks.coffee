# Description:
#   Get a stock chart
#
numeral = require('numeral')
token = process.env.HUBOT_IEX_CLOUD_TOKEN || 'NO_IEX_API_KEY'
baseURL = "https://cloud.iexapis.com/stable/stock/"

mny = (x) ->
    return numeral(x).format("($0.00 a)")

pct = (x) ->
    return numeral(x).format("0.[0000]%")

endpoint = (ticker, api) ->
    return "#{baseURL}#{ticker}/#{api}?token=#{token}"

renderChart = (robot, ticker) ->
    return new Promise (resolve, reject) ->
        robot.http(endpoint(ticker, 'time-series')).get() (err, res, body) ->
            json = JSON.parse(body)
            prices = json.map (day) -> day.close
            dates = json.map (day) -> day.date.substr(5)
            min = Math.floor (Math.min prices...)
            max = Math.ceil (Math.max prices...)
            chart = "https://image-charts.com/chart?chtt=#{ticker}&chbh=a&chd=a:#{prices.join()}&chxt=y&chs=999x250&chxr=0,#{min},#{max}&cht=lc"            
            resolve 
                title:ticker
                image_url:chart

currentPrice = (robot, ticker) ->
    return new Promise (resolve, reject) ->
        robot.http(endpoint(ticker, 'quote')).get() (err, res, body) ->
            x = JSON.parse(body)
            dir = if x.changePercent > 0 then "▲" else "▼"
            text = "#{dir} #{x.companyName} | Price: #{mny(x.latestPrice)} (#{pct(x.changePercent)}) | 52W: #{mny(x.week52Low)} - #{mny(x.week52High)} | Market Cap: #{mny(x.marketCap)} | P/E: #{x.peRatio}" 
            resolve 
                text: text

module.exports = (robot) ->

    robot.respond /stock (.*)/i, (msg) ->    
        msg.finish()            
        symbols = msg.match[1].toUpperCase().split(" ")

        for ticker in symbols 
            promise = Promise.all([
                renderChart(robot, ticker),
                currentPrice(robot,ticker)
            ])
            
            promise.then (results) ->
                attachments = results.filter (r) => r.image_url?
                text = (results.filter (r) -> r.text?)[0].text

                response =
                    text:text
                    attachments: attachments
                    username: robot.name
                    as_user: true

                console.log(JSON.stringify(response))
                msg.send response
            promise.catch (err) ->
                console.log(err)

