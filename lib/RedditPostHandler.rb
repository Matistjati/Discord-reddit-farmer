require_relative "RedditWatcher.rb"
require 'httparty'

class RedditPostHandler
    def self.check_and_send_posts(settings, receiver)
        @interval_to_sec = {"hour" => 3600, "day" => 86400, "week" => 604800, "month" => 2629744, "year" => 31556926, "all" => 1e9}

        
        settings.each do |server_id, server|
            server.subreddits.each do |subreddit_name, subreddit|
                interval = "hour"
                
                
                interval = subreddit["settings"]["interval"]

                if (Time.now.to_i - subreddit["last_post"].to_i) < @interval_to_sec[interval]
                    next
                end

                subreddit["last_post"] = Time.now.to_i

                request_link = RedditWatcher.get_request_link(subreddit_name, interval, count: subreddit["settings"]["count"])
                response = HTTParty.get(request_link, headers: RedditWatcher.get_generic_header())

                f = File.open("ligma.txt", "w")
                f.write(response)
                response["data"]["children"].each do |child|
                    data = child["data"]

                    title = data["title"]
                    url = data["url"]
                    server.send_message(subreddit_name, title, receiver, url: url)
                end
            end
        end
    end


end