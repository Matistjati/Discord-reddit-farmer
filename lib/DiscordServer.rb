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
            servers[server_id].subreddits[subreddit] = {"channel_ids" => [channel_id]}
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

    def send_message(subreddit, title, bot, content:"", url:"")
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

            # For text posts. TODO: option not to recieve text posts
            if content.length != 0
                embed.description = content
            end

            # For image posts
            if url.length != 0
                embed.image = Discordrb::Webhooks::EmbedImage.new(url: url)
            end

            # TODO: fix video posts. Unknown which format they are sent in currently

            # And away goes the message
            bot.send_embed(channel_id, embed)
        end
    end
end
