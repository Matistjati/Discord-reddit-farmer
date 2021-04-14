require 'discordrb'
require 'json'

file = File.read('credentials.json')
data_hash = JSON.parse(file)

bot = Discordrb::Bot.new token: data_hash["token"]

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

puts(bot.methods)

bot.run