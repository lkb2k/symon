#Description
# Remembers basic facts in redis
#
# Commands
#   hubot forget <fact to forget> - deletes all entries under that key
#   hubot <x> is <y>  - causes bot to remember that fact and repeat it if anyone asks

Url   = require "url"
Redis = require "redis"
inspect = require('util').inspect
nlp = require('compromise')

witticism = [
  "",
  "I heard someone say that",
  "It's been reported that",
  "I guess",
  "hm...",
  "Well,",
  "Rumor has it,",
  "As I recall,"
]

class Factoid
  subject: null
  definition: null
  question: false
  statement: false

  constructor: (@client, @rawText, @isDirectMessage) ->
    @cleanedText = @clean(rawText)
    doc = nlp(@cleanedText)
    @scrubbedText = doc.normalize().out('text')

    if @isQuestion(@scrubbedText)
      @question = true
      @subject = @extractSubjectFromQuestion(@scrubbedText)
      
    else if @isStatement(@scrubbedText)
      match = @scrubbedText.match(/(.+?)\s+(is|are)\s+(.*)/)
      if match
        console.log(match)        
        @statement = true
        @subject = @extractNounPhrase(match[1])
        @verb = match[2]
        @definition = match[3] 

    console.log('found question: '+@subject) if @question
    console.log('found statement: '+@scrubbedText) if @statement

  process: (msg) ->
    @answer(msg) if @question
    @store(msg, @subject, @cleanedText) if @statement

  store: (msg, key, value) ->
    @client.zadd(key, 0, "#{value}")
    console.log('stored: '+key+'|'+value)
    @acknowledge(msg, value) if @isDirectMessage

  acknowledge: (msg, stored) -> 
    username = msg.message.user.name
    msg.send msg.random [
      "Ok, #{username}.",
      "Got it, #{username}."
      "#{username}: Understood.",
      "You betcha, #{username }.",
      "わかりました, #{username}.",
      "सही सभी, #{username}", ".#{username}،فهم"
      "Duly noted.", "Acknowledged.",
      "#{username}: Acknowledged.",
      "It has been recorded.",
      "That makes sense."
      "#{username}, so what you're saying is that #{stored}?  I think I got it…"
      "Recorded: \"#{username} thinks that #{stored}.\""
    ]


  answer: (msg) ->
    @client.zrange @subject, 0, -1, (err, definition) =>
      if definition.length
        msg.send "#{msg.random witticism} #{msg.random definition}"

      else if @isDirectMessage
        username = msg.message.user.name
        msg.send msg.random [
          "no clue #{username}"
          "bugger all #{username}, you've got me."
          "I wish I knew"
          "no idea."
          "I don't know, maybe Jun-Dai knows"
          "How should I know?  Ask expweb info"
        ] 

  extractNounPhrase: (input) ->    
    noun = nlp(input).nouns().toSingular().out('text')
    output = noun || input
    console.log(input+' -> '+output)
    return output.replace /^\s+|\s+$/g, '' # trim again

  isStatement: (input) ->
    return /\s+(is|are)\s.*[^?]$/i.test input      

  clean: (input) -> 
    #regexes stolen from infobot

    #strip profanity
    input = input.replace /th(e|at|is) (((m(o|u)th(a|er) ?)?fuck(in\'?g?)?|hell|heck|(god-?)?damn?(ed)?) ?)+/i, ''

    #re-order what x is? to what is x
    match = /(where|what|who)\s+(\S.*)\s+(is|are)/i.exec input
    input = "#{match[1]} #{match[3]} #{match[2]}" if match

    input = input.replace /,? any(hoo?w?|ways?)/ig, ''
    input = input.replace /,?\s*(pretty )*please\??\s*$/i, '?'
    input = input.replace /the hell/i, ''
    input = input.replace /wtf/i, 'what'
    input = input.replace /this thingy? (called )?/gi, ''
    input = input.replace /ha(s|ve) (an?y?|some|ne) (idea|clue|guess|seen) /i, 'know'
    input = input.replace /(does )?(any|ne|some) ?(1|one|body) know /ig, ''
    input = input.replace /do you know /ig, ''
    input = input.replace /can (you|u|((any|ne|some) ?(1|one|body)))( please)? tell (me|us|him|her)/ig, ''
    input = input.replace /where (\S+) can \S+ (a|an|the)?/ig, ''
    input = input.replace /(can|do) (i|you|one|we|he|she) (find|get)( this)?/i, ''
    input = input.replace /(i|one|we|he|she) can (find|get)/ig, 'is'
    input = input.replace /(the )?(address|url) (for|to) /i, ''
    input = input.replace /(where is )+/i, 'where is '
    input = input.replace /^\s*and\s?,? /i, ''
    input = input.replace /^\s*i (think|feel) (that )?/i, ''

    input = input.replace /\s+/, " "
    input = input.replace /\s+$/, ''

    return input

  extractSubjectFromQuestion: (input) -> 
      # fix the string.
    input = input.replace /\s+\?$/, '?'
    input = input.replace /^whois /i, ''
    input = input.replace /^who is /i, ''
    input = input.replace /^what is (a|an)?/i, ''
    input = input.replace /^how do i /i, ''
    input = input.replace /^how do you /i, ''
    input = input.replace /^wh(o|at|ere)\s+(is|are|about) /i, ''
    input = input.replace /^where can i (find|get|download) /ig, ''
    input = input.replace /^how about /i, ''

    # clear the string of useless words.
    input = input.replace /^(stupid )?q(uestion)?:\s+/i, ''
    input = input.replace /^(does )?(any|ne)(1|one|body) know /i, ''
    input = input.replace /^[uh]+m*[,\.]* +/i, ''
    input = input.replace /^well([, ]+)/i, ''
    input = input.replace /^still([, ]+)/i, ''
    input = input.replace /^(gee|boy|golly|gosh)([, ]+)/i, ''
    input = input.replace /^(well|and|but|or|yes)([, ]+)/i, ''
    input = input.replace /^o+[hk]+(a+y+)?([,. ]+)/i, ''
    input = input.replace /^g(eez|osh|olly)([,. ]+)/i, ''
    input = input.replace /^w(ow|hee|o+ho+)([,. ]+)/i, ''
    input = input.replace /^heya?,?( folks)?([,. ]+)/i, ''
    input = input.replace /\s*[\/?!]*\?+\s*$/, ''

    input = input.replace /wh(o|at|ere|en)/i, ''
    input = input.replace /\s+/, " "
    input = input.replace /\s+$/, ''
    input = input.replace /^\s+/, ''
    
    return @extractNounPhrase(input)

  isQuestion: (input) ->
    if /where are you\??$/i.test input then return false
    if /\?\s*$/.test input then return true
    if /^what's/i.test input then return true
    if /^where's/i.test input then return true
    if /^wh(o|at|ere|en)\s+/.test input then return true
    if /(cell|e-?mail|url)$/.test input then return true
    return false

  @forget = (client, msg, input) ->
    normalizedInput = nlp(input).nouns().toSingular().out('text')
    client.del input
    client.del normalizedInput
    msg.send "It is lost to the winds of time."



# sets up hooks to persist the brain into redis.
module.exports = (robot) ->
  redisUrl   = process.env.REDIS_URL || 'redis://localhost:6379'
  client = Redis.createClient(redisUrl)

  client.on "error", (err) ->
    console.log(err)
    robot.logger.error err

  client.on "connect", ->
    console.log("connected to redis")
    robot.logger.debug "Successfully connected to Redis"

  robot.respond /(.*)/i, (msg) ->    
    fact = new Factoid(client, msg.match[1], true).process(msg)

  robot.respond /forget (.*)/i, (msg) ->
    Factoid.forget(client, msg,msg.match[1])

  robot.catchAll (msg) ->
    if msg.message.text
      new Factoid(client, msg.message.text, false).process(msg)