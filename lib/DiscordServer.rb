class DiscordServer
    attr_accessor :subreddits, :id, :settings, :posts

    # Contains information about which subreddits each channel in the server follows
    def initialize(id, settings)
        @id = id
        @subreddits = {}

        settings["subreddits"].each do |name, subreddit_settings|
            @subreddits[name] = subreddit_settings
        end
        @posts = {}
    end

    def self.get_server_hash(servers)
        server_hash = {}
        servers.each do |id, server|
            server_hash[id] = {"subreddits" => server.subreddits}
        end

        return server_hash
    end

    def self.get_info(event, subreddit, servers)
        embed = Discordrb::Webhooks::Embed.new()

        embed.title = "Info for #{event.server.name}"
        server_id = event.server.id.to_s

        if servers.key?(server_id) and servers[server_id].subreddits.length > 0
            info = "This server is following these subreddits:\n"
            servers[server_id].subreddits.each do |subreddit, channel_ids|
                info += subreddit + "\n"
            end
            embed.description = info
        else
            embed.description = "This server is currently not using the reddit farmer bot. Type !help to get started."
        end

        return embed
    end

    def self.change_setting(subreddit, setting_name, value, event, servers)
        server_id = event.server.id.to_s
        if not servers.key?(server_id)
            return "You are following any subreddits on this server yet"
        end


        server = servers[server_id]

        if not server.subreddits.key?(subreddit)
            return "You are not following the subreddit #{subreddit}"
        end

        if setting_name == "count"
            int_value = value.to_i
            if int_value == 0
                return "Count has to be a whole number or non-zero"
            end
            server.subreddits[subreddit]["settings"]["count"] = int_value
        elsif setting_name == "interval"
            if not ["hour", "day", "week", "month", "year", "all"].include?(value)
                return "The value for interval must be hour, day, week, month, year or all"
            end
            server.subreddits[subreddit]["settings"]["interval"] = value
        elsif setting_name == "last_post"
            server.subreddits[subreddit]["last_post"] = value.to_i
        else
            return "Setting not found"
        end

        return servers
    end

    def self.parse_saved_servers(server_hash)
        # Sample structure
        # last_post is a timestamp
        #{
        #   "server_id": 
        #   {
        #       "subreddits":
        #       {
        #           "okbuddyretard": {"channel_ids": [69420, 31415926535897932384], "last_post": 3285890, settings: {"interval": "day", "count": 3}},
        #           "okbuddybaka": {"channel_ids": [133769, 628318530718]}
        #       }
        #   }
        #   ...
        #}
        servers = {}

        server_hash.each do |id, settings|
            servers[id] = DiscordServer.new(id, settings)
        end

        return servers
    end

    def self.add_subreddit(server_id, channel_id, subreddit, servers)
        # TODO: verify existence of subreddit
        if servers.key?(server_id)
            if servers[server_id].subreddits.key?(subreddit)
                return "You are already following this subreddit"
            end
            servers[server_id].subreddits[subreddit] = {"channel_ids" => [channel_id], "last_post" => 10, "settings" => {"interval" => "day", "count" => 3}}
        else
            # Construct the tree demonstrated above
            settings = {"subreddits" => {subreddit => {"channel_ids" => [channel_id], "last_post" => 0, "settings" => {"interval" => "day", "count" => 3}}}}

            server = DiscordServer.new(server_id, settings)
            servers[server_id] = server
        end

        return servers
    end

    def self.remove_subreddit(server_id, subreddit, servers)
        # Simply remove the undesired subreddit from the tree
        if servers.key?(server_id)
            if servers[server_id].subreddits.key?(subreddit)
                servers[server_id].subreddits.delete(subreddit)
            else
                return "You were never following #{subreddit}"
            end
        else
            return "You are not following any subreddits in this server"
        end

        return servers
    end

    def send_message(subreddit, title, bot, content: nil, image_url: nil)
        # Avoid async issues. Should probably use locks to be safe (unfollowing a channel = deleting a key, could lead to exception)
        if not @subreddits.key?(subreddit)
            return
        end

        # Given a post from a particular subreddit, send out the post to all relevant channels
        @subreddits[subreddit]["channel_ids"].each do |channel_id|

            # Create an embed, a detailed message
            embed = Discordrb::Webhooks::Embed.new()

            # Title of the post
            embed.title = title

            if content != nil
                embed.description = content
            end

            # For image posts
            if image_url != nil and image_url.length != 0
                embed.image = Discordrb::Webhooks::EmbedImage.new(url: image_url)
            end


            # And away goes the message
            bot.send_embed(channel_id, embed)
        end
    end

    def send_video(subreddit, bot, title, video_url)
        # Avoid async issues. Should probably use locks to be safe (unfollowing a channel = deleting a key, could lead to exception)
        if not @subreddits.key?(subreddit)
            return
        end

        # Given a post from a particular subreddit, send out the post to all relevant channels
        @subreddits[subreddit]["channel_ids"].each do |channel_id|
            # And away goes the message
            bot.send_message(channel_id, title)
            bot.send_message(channel_id, video_url)
        end
    end
end
