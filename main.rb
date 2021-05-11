require 'discordrb'
require 'discordrb/webhooks'
require 'json'
require_relative 'lib/ContentProvider.rb'
require_relative 'lib/ContentReceiver.rb'
require_relative 'lib/DiscordBot.rb'
require_relative 'lib/RedditWatcher.rb'
require_relative 'lib/DiscordServer.rb'


# Run the bot in another thread, allowing for it to call all the bot.command methods above all while allowing us to loop below. This loop will be used to check reddit posts
#Bot.instance.run()

#puts(servers)
#puts(subreddit_listeners)

# Purely testing, send a message to every subreddit
# while true
#     sleep(5)
#     #bot.send_message(channel_id, 'Bot is now active!')
#     Bot.instance.subreddit_listeners.keys.each do |subreddit|
#         Bot.instance.subreddit_listeners[subreddit].each do |subscriber|
#             Bot.instance.servers[subscriber].send_message(subreddit, "I miss my wife", "", "https://preview.redd.it/wj51ubdgdhv61.jpg?width=960&crop=smart&auto=webp&s=f1340e339ad570663f1bafad96fe3d805a80220e")
#         end
#     end
# end

bot = DiscordBot.new()
content_provider = RedditWatcher.new(bot)

testServer = DiscordServer.new(821667830079946792, {"subreddits"=> {"okbuddyretard"=> {"interval"=> "day", "channel_ids" => [821667830079946796]}}})
content_provider.check_for_posts({"okbuddyretard"=> [testServer]})