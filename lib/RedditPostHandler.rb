require_relative "RedditWatcher.rb"
require 'httparty'
require_relative "TokenBucket"

class RedditPostHandler
    def self.check_and_send_posts(watcher, settings, receiver, bucket)
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
                if not bucket.request_allowed?()
                    sleep(bucket.time_to_next_refill + 1)
                end
                attempts = 0

                begin
                    response = HTTParty.get(request_link, headers: RedditWatcher.get_generic_header())
                rescue
                    attempts += 1
                    if attempts > 2
                        puts("Critical error, can't send request")
                        next
                    end
                    watcher.refresh_token()
                    retry
                end
                
                bucket.request_sent()

                response["data"]["children"].each do |child|
                    data = child["data"]

                    title = data["title"]

                    if not data.key?("post_hint")
                        text_content = data["selftext"]
                        # Too long for discord
                        if text_content.length > 2000
                            next
                        end
                        
                        server.send_message(subreddit_name, title, receiver, content: text_content)
                    elsif data["post_hint"].include? "video"
                        video_url = data["url_overridden_by_dest"]
                        server.send_video(subreddit_name, receiver, title, video_url)
                    elsif data["post_hint"].include? "image"
                        image_url = data["url"]
                        server.send_message(subreddit_name, title, receiver, image_url: image_url)
                    end
                end
            end
        end
    end
end