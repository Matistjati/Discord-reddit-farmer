class Server
    attr_accessor :subreddits, :id

    # Contains information about which subreddits each channel in the server follows
    def initialize(id, settings)
        @id = id
        @subreddits = {}
        settings["subreddits"].each do |name, subreddit_settings|
            @subreddits[name] = subreddit_settings
        end
    end


    def send_message(subreddit, title, content="", url="")
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
            Bot.instance.send_embed(channel_id, embed)
        end
    end
end
