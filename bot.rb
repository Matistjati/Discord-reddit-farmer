require 'discordrb'
require 'discordrb/webhooks'
require 'json'

if not File.exists?('credentials.json')
    puts("No credentials file found. Will now abort.")
    exit()
end
credentials = File.read('credentials.json')
token = JSON.parse(credentials)["token"]

$bot = Discordrb::Commands::CommandBot.new token: token, prefix: '!'

def save_servers(servers)
    server_hash = {}
    servers.each do |id, server|
        server_hash[id] = {"subreddits" => server.subreddits}
    end

    File.open("bot data.json","w") do |f|
        f.write(server_hash.to_json)
    end
end

class Server
    attr_accessor :subreddits, :id

    def initialize(id, settings)
        @id = id
        @subreddits = {}
        settings["subreddits"].each do |name, subreddit_settings|
            @subreddits[name] = subreddit_settings
        end
    end

    def send_message(subreddit, title, content="", url="")
        if not @subreddits.key?(subreddit)
            return
        end

        @subreddits[subreddit]["channel_ids"].each do |channel_id|

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

if File.exists?('bot data.json')
    file = File.read('bot data.json')
    bot_info = JSON.parse(file)

    bot_info.each do |id, settings|
        servers[id] = Server.new(id, settings)
        
        settings["subreddits"].each do |subreddit|
            if subreddit_listeners.key?(subreddit.first)
                subreddit_listeners[subreddit.first].append(id)
            else
                subreddit_listeners[subreddit.first] = [id]
            end
        end
    end
end


# A command for finding the latency to the bot
$bot.command :ping do |event|
    event.respond("Pong! :ping_pong: Responded within: #{(Time.now - event.timestamp).round(2)} seconds")
end

$bot.command :follow do |event, subreddit|

    server_id = event.server.id.to_s
    # TODO: verify existence of subreddit
    if servers.key?(server_id)
        servers[server_id].subreddits[subreddit] = {"channel_ids" => [event.channel.id]}
    else
        settings = {"subreddits" => {subreddit => {"channel_ids" => [event.channel.id]}}}

        server = Server.new(server_id, settings)
        servers[server_id] = server
    end


    if not subreddit_listeners.key?(subreddit)
        subreddit_listeners[subreddit] = [server_id]
    else
        subreddit_listeners[subreddit].append(server_id)
    end

    save_servers(servers)

    return "Now following: #{subreddit}"

end


$bot.command :unfollow do |event, subreddit|
    server_id = event.server.id.to_s
    if servers.key?(server_id)
        if servers[server_id].subreddits.key?(subreddit)
            servers[server_id].subreddits.delete(subreddit)
        else
            return "You were never following #{subreddit}"
        end
    else
        return "You are not following any channels"
    end

    save_servers(servers)

    puts(servers)

    return "No longer following: #{subreddit}"
end

$bot.command :info do |event, subreddit|
    server_id = event.server.id.to_s
    embed = Discordrb::Webhooks::Embed.new()

    embed.title = "Info for #{event.server.name}"

    if servers.key?(server_id)
        info = "This server is following these subreddits:\n"
        servers[server_id].subreddits.each do |subreddit, channel_ids|
            info += subreddit + "\n"
        end
        embed.description = info
    else
        embed.description = "This server is currently not using the reddit farmer bot. Type !help to get started."
    end


    $bot.send_message(event.channel.id, "", false, embed)
end

$bot.command :exit do |event, subreddit|
    save_servers(servers)
    exit()
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
    sleep(5)
    #bot.send_message(channel_id, 'Bot is now active!')
    subreddit_listeners.keys.each do |subreddit|
        subreddit_listeners[subreddit].each do |subscriber|
            servers[subscriber].send_message(subreddit, "I miss my wife", "", "https://preview.redd.it/wj51ubdgdhv61.jpg?width=960&crop=smart&auto=webp&s=f1340e339ad570663f1bafad96fe3d805a80220e")
        end
    end
end
