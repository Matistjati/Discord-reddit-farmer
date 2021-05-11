require_relative "ContentReceiver"
require_relative "DiscordServer"

class DiscordBot
    include ContentReceiver
    attr_accessor :bot, :servers, :subreddit_listeners

    def initialize()
        token = read_token()
        @bot = Discordrb::Commands::CommandBot.new token: token, prefix: '!'
        initialize_server_data()
        register_commands()

        @bot.run(true)
    end

    # Save the current state of the bot (all discord server, which subreddits they follow and the corresponding channels)
    def save_state()
        server_hash = {}
        servers.each do |id, server|
            server_hash[id] = {"subreddits" => server.subreddits}
        end

        File.open("data/bot data.json","w") do |f|
            f.write(server_hash.to_json)
        end
    end

    def initialize_server_data()
        @servers = {}

        # Servers basically mimics the structure of the json document which can be seen below. Its key is the server id and the value is a server object, which is practically identical to 
        # the object under the server_id key.
        # It is structured in this way to allow for easy lookup from the pov of knowing a server id (when someone messages you follow/unfollow)
        # It is also easy to find which channels "listen" to a particular subreddit (want to recieve its posts)
        # I've also left room for other metadata, as each server_id key can also contain more info, as well as the individual subreddit keys
        # Could be info such as how many posts they want per day
        # Example data:
        #
        #{
        #   "server_id": 
        #   {
        #       "subreddits":
        #       {
        #           "okbuddyretard": {"channel_ids": [69420, 31415926535897932384]},
        #           "okbuddybaka": {"channel_ids": [133769, 628318530718]}
        #       }
        #   }
        #   ...
        #}



        @subreddit_listeners = {}
        # We also want to know which servers given a subreddit
        # This is the purpose of subreddit_listeners: the key is the name of a subreddit and the value is an array of the server ids which want to recieve posts from that subreddit
        # The channel ids are then stored in the server's data, as can be seen above

        # No problem if it doesn't exist
        if File.exists?('data/bot data.json')
            file = File.read('data/bot data.json')
            bot_info = JSON.parse(file)

            # Just going through the document as can be seen above
            bot_info.each do |id, settings|
                @servers[id] = DiscordServer.new(id, settings)
                
                # subreddit_name: [id1, id2, ...]
                # Described more in-depth above
                settings["subreddits"].each do |subreddit|
                    if @subreddit_listeners.key?(subreddit.first)
                        @subreddit_listeners[subreddit.first].append(id)
                    else
                        @subreddit_listeners[subreddit.first] = [id]
                    end
                end
            end
        end
    end

    def register_commands()
        # A command for finding the latency to the bot
        @bot.command :ping do |event|
            event.respond("Pong! :ping_pong: Responded within: #{(Time.now - event.timestamp).round(2)} seconds")
        end

        # A bot command stating that you want the channel the message is sent from to listen to a particular subreddit
        @bot.command :follow do |event, subreddit|

            server_id = event.server.id.to_s
            # TODO: verify existence of subreddit
            if @servers.key?(server_id)
                @servers[server_id].subreddits[subreddit] = {"channel_ids" => [event.channel.id]}
            else
                # Construct the tree demonstrated above
                settings = {"subreddits" => {subreddit => {"channel_ids" => [event.channel.id]}}}

                server = Server.new(server_id, settings)
                @servers[server_id] = server
            end

            # Keep subreddit_listeners up to date
            if not @subreddit_listeners.key?(subreddit)
                @subreddit_listeners[subreddit] = [server_id]
            else
                @subreddit_listeners[subreddit].append(server_id)
            end

            # We always save after each operation that modifies the bot state. Probably not very good performance-wise, but shouldn't be an issue if used small-scale
            save_state()

            # User feedback
            return "Now following: #{subreddit}"
        end

        # A bot command stating that no you longer want to follow a subreddit
        @bot.command :unfollow do |event, subreddit|
            server_id = event.server.id.to_s

            # Simply remove the undesired subreddit from the tree
            if @servers.key?(server_id)
                if @servers[server_id].subreddits.key?(subreddit)
                    @servers[server_id].subreddits.delete(subreddit)
                else
                    return "You were never following #{subreddit}"
                end
            else
                return "You are not following any subreddits in this server"
            end

            # We always save after each operation that modifies the bot state. Probably not very good performance-wise, but shouldn't be an issue if used small-scale
            save_state()

            # User feedback
            return "No longer following: #{subreddit}"
        end

        # Give some bare-bones information about which subreddits the server follows. TODO: display the names of the channels following particular subreddits.
        # Done by iterating all channels of server and matching their ids with our stored channel ids
        @bot.command :info do |event, subreddit|
            server_id = event.server.id.to_s
            embed = Discordrb::Webhooks::Embed.new()

            embed.title = "Info for #{event.server.name}"

            if @servers.key?(server_id)
                info = "This server is following these subreddits:\n"
                @servers[server_id].subreddits.each do |subreddit, channel_ids|
                    info += subreddit + "\n"
                end
                embed.description = info
            else
                embed.description = "This server is currently not using the reddit farmer bot. Type !help to get started."
            end


            @bot.send_message(event.channel.id, "", false, embed)
        end

        # A peaceful exit, make sure to save our state
        @bot.command :exit do |event, subreddit|
            save_state()
            exit()
        end

        # Testing command, this is how we would send out a post from a particular subreddit
        @bot.command :pingreddit do |event, subreddit|

            server_ids = @subreddit_listeners[subreddit]
            
            server_ids.each do |id|
                servers[id].send_message(subreddit, "lol", "lmao")
            end
            return ""
        end

    end

    def send_embed(channel_id, embed)
        @bot.send_message(channel_id, "", false, embed)
    end

    # Read in the bot credentials. These are not stored in github for obvious reasons
    def read_token()
        path = 'data/discord_credentials.json'
        if not File.exists?(path)
            puts("No discord credentials file found. Will now abort.")
            exit()
        end
        credentials = File.read(path)
        return JSON.parse(credentials)["token"]
    end


end