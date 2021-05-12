require 'discordrb'
require 'discordrb/webhooks'
require 'json'
require_relative 'lib/ContentProvider.rb'
require_relative 'lib/ContentReceiver.rb'
require_relative 'lib/DiscordBot.rb'
require_relative 'lib/RedditWatcher.rb'
require_relative 'lib/DiscordServer.rb'


bot = DiscordBot.new()
content_provider = RedditWatcher.new(bot)

while true
    sleep(2)
    content_provider.check_for_posts(bot.servers)
end