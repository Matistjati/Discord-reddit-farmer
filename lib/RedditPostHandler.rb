require_relative "RedditWatcher.rb"
require 'httparty'

class RedditPostHandler
    def self.check_and_send_posts(settings, receiver)
        settings.each do |subreddit, servers|
            servers.each do |server|
                interval = "hour"
                if server.settings.key?("interval")
                    interval = server.settings["interval"]
                end

                request_link = RedditWatcher.get_request_link(subreddit, interval, count: 10)
                response = HTTParty.get(request_link, headers: RedditWatcher.get_generic_header())

                f = File.open("ligma.txt", "w")
                f.write(response)
                response["data"]["children"].each do |child|
                    data = child["data"]

                    title = data["title"]
                    url = data["url"]
                    server.send_message(subreddit, title, receiver, url: url)
                end
            end
        end
    end


end