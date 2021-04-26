require 'discordrb'
require 'discordrb/webhooks'
require 'json'

credentials = File.read('credentials.json')
token = JSON.parse(credentials)["token"]

$bot = Discordrb::Commands::CommandBot.new token: token, prefix: '!'


class Server
    attr_accessor :subreddits, :id

    def initialize(id, settings)
        @id = id
        @subreddits = {}
        settings["subreddits"].each do |subreddit|
            @subreddits[subreddit["name"]] = subreddit["channel_ids"]
        end
    end

    def send_message(subreddit, title, content="", url="")
        @subreddits[subreddit].each do |channel_id|

            embed = Discordrb::Webhooks::Embed.new()

            embed.title = title
            if content.length != 0
                embed.description = content
            end
            if url.length != 0
                embed.image = Discordrb::Webhooks::EmbedImage.new(url: url)
            end

            $bot.send_message(channel_id, "", false, embed)
        end
    end
end



servers = {}
subreddit_listeners = {}

file = File.read('bot data.json')
bot_info = JSON.parse(file)

bot_info.each do |id, settings|
    servers[id] = Server.new(id, settings)
    
    settings["subreddits"].each do |subreddit|
        if subreddit_listeners.key?(subreddit["name"])
            subreddit_listeners[subreddit["name"]].append(id)
        else
            subreddit_listeners[subreddit["name"]] = [id]
        end
    end
end


$bot.command :ping do |event|
    event.respond("Pong! :ping_pong: Responded within: #{(Time.now - event.timestamp).round(2)} seconds")
end

$bot.command :follow do |event, subreddit|

    # TODO: verify existence of subreddit, validation of server etc
    servers[event.server.id.to_s].subreddits[subreddit] = [event.channel.id]
    if not subreddit_listeners.key?(subreddit)
        subreddit_listeners[subreddit] = [event.server.id.to_s]
    else
        subreddit_listeners[subreddit].append(event.server.id.to_s)
    end

    return "Now following: #{subreddit}"

end

$bot.command :pingreddit do |event, subreddit|

    server_ids = subreddit_listeners[subreddit]
    
    server_ids.each do |id|
        servers[id].send_message(subreddit, "lol", "lmao")
    end
    return ""
end


$bot.run(true)

#puts(servers)
#puts(subreddit_listeners)

while true
    sleep(2)
    #bot.send_message(channel_id, 'Bot is now active!')
    subreddit_listeners.keys.each do |subreddit|
        subreddit_listeners[subreddit].each do |subscriber|
            servers[subscriber].send_message(subreddit, "I miss my wife", "", "https://preview.redd.it/wj51ubdgdhv61.jpg?width=960&crop=smart&auto=webp&s=f1340e339ad570663f1bafad96fe3d805a80220e")
        end
    end
end
