

require 'discordrb'

bot = Discordrb::Bot.new token: 'ODIxNjY4MDIyMTc5NDYzMTg5.YFHD-g.vpSpk-SbQDOIBatXh0u4xXfdK7s'

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

puts(bot.methods)

bot.run