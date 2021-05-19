require_relative "ContentReceiver"
require_relative "DiscordServer"

class DiscordBot
    include ContentReceiver
    attr_accessor :bot, :servers

    def initialize(server_manager: DiscordServer)
        @server_manager = server_manager
        @data_path = "data/discord_data.json"
        token = read_token()
        @bot = Discordrb::Commands::CommandBot.new token: token, prefix: '$'
        initialize_server_data()
        register_commands()



        @bot.run(true)
    end

    # Save the current state of the bot (all discord server, which subreddits they follow and the corresponding channels)
    def save_state()
        server_hash = @server_manager.get_server_hash(@servers)

        File.open(@data_path,"w") do |f|
            f.write(server_hash.to_json)
        end
    end

    def initialize_server_data()
        @servers = {}

        # No problem if it doesn't exist, servers has already been empty-initialized

        if File.exists?(@data_path)
            file = File.read(@data_path)
            server_hash = JSON.parse(file)
            @servers = @server_manager.parse_saved_servers(server_hash)
        end
    end

    def unfollow(server_id, subreddit)
        result = @server_manager.remove_subreddit(server_id, subreddit, @servers)

        if result.is_a? String
            return result
        else
            @servers = result
        end

        # We always save after each operation that modifies the bot state. Probably not very good performance-wise, but shouldn't be an issue if used small-scale
        save_state()

        # User feedback
        return "No longer following: #{subreddit}"
    end

    def register_commands()
        # A command for finding the latency to the bot
        @bot.command :ping do |event|
            event.respond("Pong! :ping_pong: Responded within: #{(Time.now - event.timestamp).round(2)} seconds")
        end

        # A bot command stating that you want the channel the message is sent from to listen to a particular subreddit
        @bot.command :follow do |event, subreddit|

            server_id = event.server.id.to_s
            result = @server_manager.add_subreddit(server_id, event.channel.id, subreddit, @servers)

            if result.is_a? String
                return result
            else
                @servers = result
            end
            
            # We always save after each operation that modifies the bot state. Probably not very good performance-wise, but shouldn't be an issue if used small-scale
            save_state()

            # User feedback
            return "Now following: #{subreddit}"
        end

        # A bot command stating that no you longer want to follow a subreddit
        @bot.command :unfollow do |event, subreddit|
            server_id = event.server.id.to_s
            return unfollow(server_id, subreddit)
        end

        # Give some bare-bones information about which subreddits the server follows. TODO: display the names of the channels following particular subreddits.
        # Done by iterating all channels of server and matching their ids with our stored channel ids
        @bot.command :info do |event, subreddit|
            server_id = event.server.id.to_s
            embeds = @server_manager.get_info(event, subreddit, @servers)

            embeds.each do |embed|
                @bot.send_message(event.channel.id, "", false, embed)
            end
        end

        # A peaceful exit, make sure to save our state
        @bot.command :exit do |event, subreddit|

            user_id = event.author.id
            if user_id == 217704901889884160
                save_state()
                exit()
            else
                return "You lack sufficient permissions to use this command"
            end
        end

        # Testing command, this is how we would send out a post from a particular subreddit
        @bot.command :showhash do |event, subreddit|
            user_id = event.author.id
            if user_id == 217704901889884160
                return @server_manager.get_server_hash(@servers).to_json()
            else
                return "You lack sufficient permissions to use this command"
            end
        end

        @bot.command :setting do |event, subreddit, setting_name, value|

            
            if subreddit == nil or setting_name == nil or value == nil
                return "Incorrect format"
            end
            result = @server_manager.change_setting(subreddit, setting_name, value, event, @servers)

            if result.is_a? String
                return result
            else
                @servers = result
            end

            save_state()

            return "#{setting_name} for #{subreddit} is now #{value}"
        end

    end

    def send_embed(channel_id, embed)
        @bot.send_message(channel_id, "", false, embed)
    end

    def send_message(channel_id, content)
        @bot.send_message(channel_id, content, false)
    end

    # Read in the bot credentials. These are not stored in github for obvious reasons
    def read_token()
        credentials_path = 'data/discord_credentials.json'
        if not File.exists?(credentials_path)
            puts("No discord credentials file found. Will now abort.")
            exit()
        end
        credentials = File.read(credentials_path)
        return JSON.parse(credentials)["token"]
    end


end