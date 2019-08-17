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
  isQuestion: false
  isStatement: false

  constructor: (@rawText) ->
    doc = nlp(rawText)
    @normalizedText = doc.normalize().out('text')
    @scrubbedText = @constructor.clean(@normalizedText)

    if @constructor.isQuestion(@scrubbedText)
      @isQuestion = true
      @subject = @constructor.extractSubjectFromQuestion(@scrubbedText)
    else if @constructor.isStatement(@scrubbedText)
      match = @scrubbedText.match(/(.*)\s+(is|are)\s(.*)/)
      if match
        @isStatement = true
        @subject = @constructor.extractNounPhrase(match[1])
        @verb = match[2]
        @definition = match[3] 

  @extractNounPhrase: (input) ->
    noun = nlp(input).nouns().toSingular().out('text')
    return (noun || input).replace /^\s+|\s+$/g, ''

  @isStatement = (input) ->
    return /\s+(is|are)\s.*[^?]$/i.test input      

  @clean = (input) -> 
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

    input = input.replace /\s+/, " "
    input = input.replace /\s+$/, ''
    input = input.toLowerCase();

    return input

  @extractSubjectFromQuestion = (input) -> 
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

    return Factoid.extractNounPhrase(input)

  @isQuestion = (input) ->
    if /where are you\??$/i.test input then return false
    if /\?\s*$/.test input then return true
    if /^what's/i.test input then return true
    if /^where's/i.test input then return true
    if /^wh(o|at|ere|en)\s+/.test input then return true
    if /(cell|e-?mail|url)$/.test input then return true
    return false

normalize = (input) ->
  return Factoid.clean(input)

question = (input) ->
  return Factoid.isQuestion(input)

statement = (input) ->
  Factoid.isStatement(input)

trim = (input) ->
  return Factoid.extractSubjectFromQuestion(input)

evaluate = (client,msg,input, factoid, isResponse=false) ->
  username = msg.message.user.name

  if factoid.isQuestion
    console.log('got a question for ya')
    subject = factoid.subject
    client.zrange subject, 0, -1, (err, definition) ->

      if definition.length
        msg.send "#{msg.random witticism} #{subject} #{msg.random definition}" if definition.length

      else msg.send msg.random [
        "no clue #{username}"
        "bugger all #{username}, you've got me."
        "I wish I knew"
        "no idea."
        "I don't know, maybe Jun-Dai knows"
        "How should I know?  Ask expweb info"
      ] if isResponse

  else if factoid.isStatement
    console.log('found a fact: '+factoid.scrubbedText)
    client.zadd(factoid.subject, 0, "#{factoid.verb} #{factoid.definition}")

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
      "#{username}, so what you're saying is that #{factoid.scrubbedText}?  I think I got it…"
      "Recorded: \"#{username} thinks that #{factoid.scrubbedText}.\""
    ] if isResponse


# sets up hooks to persist the brain into redis.
module.exports = (robot) ->
  info   = Url.parse process.env.REDISTOGO_URL || 'redis://localhost:6379'
  client = Redis.createClient(info.port, info.hostname)

  client.on "error", (err) ->
    robot.logger.error err

  client.on "connect", ->
    robot.logger.debug "Successfully connected to Redis"

  robot.respond /(.*)/i, (msg) ->
    message = normalize(msg.match[1])
    evaluate(client,msg,message,fact, true)

  robot.respond /forget (.*)/i, (msg) ->
    client.del msg.match[1]
    msg.send "It is already forgotten."

  robot.catchAll (msg) ->
    if msg.message.text
      fact = new Factoid(msg.message.text)
      console.log Object(fact)

      message = normalize(msg.message.text)
      evaluate(client,msg,message,fact)
