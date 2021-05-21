require_relative "RedditWatcher.rb"
require 'httparty'
require_relative "TokenBucket"

class RedditPostHandler
    def self.log_error(json_data)
        puts("Error. Json saved in last_error.txt")
        temp = open("last_error.txt", "w")
        temp.write(json_data)
        temp.close()
    end


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

                if response.code == 200
                    temp = open("ligma.txt", "w")
                    temp.write(response)
                    temp.close()

                    post_count = response["data"]["children"].length
                    server.send_message(subreddit_name, receiver, "#{post_count} post#{post_count == 1 ? "" : "s"} from r/#{subreddit_name}")
                    response["data"]["children"].each do |child|
                        data = child["data"]

                        title = data["title"]
                        encoding_options =
                        {
                            :invalid           => :replace,  # Replace invalid byte sequences
                            :undef             => :replace,  # Replace anything not defined in ASCII
                            :replace           => '',        # Use a blank for those replacements
                            :universal_newline => true       # Always break lines with \n
                        }

                        title = title.encode(Encoding.find('ASCII'), encoding_options)
                        title = title[0,254]

                        if not data.key?("post_hint")
                            text_content = data["selftext"]
                            if text_content == nil
                                puts("Could not find content for text post. Json saved in last_error.txt")
                                temp = open("last_error.txt", "w")
                                temp.write(data.to_json())
                                temp.close()
                                return
                            end
                            # Too long for discord
                            if text_content.length > 2000
                                next
                            end
                            
                            if data.key?("url")
                                server.send_url(subreddit_name, receiver, title, data["url"])
                            else
                                server.send_message(subreddit_name, receiver, title, content: text_content)
                            end
                        elsif data["post_hint"].include? "video"
                            puts("Video_debug.txt saved")
                            temp = open("video_debug.txt", "w")
                            temp.write(data.to_json())
                            temp.close()

                            video_url = data["url_overridden_by_dest"]
                            if video_url == nil or not video_url.include?("mp4")
                                if data.key?("secure_media") and data["secure_media"].length > 0 and data["secure_media"].key?("reddit_video")
                                    video_url = data["secure_media"]["reddit_video"]["fallback_url"]
                                elsif data.key?("media") and data["media"].length > 0 and data["media"].key?("reddit_video")
                                    video_url = data["media"]["reddit_video"]["fallback_url"]
                                else
                                    video_url = data["url_overridden_by_dest"]
                                end
                            end

                            if video_url == nil
                                next
                            end

                            server.send_url(subreddit_name, receiver, title, video_url)
                        elsif data["post_hint"].include? "image"
                            image_url = data["url"]
                            if image_url == nil
                                image_url = data["url_overridden_by_dest"]
                            end
                            server.send_message(subreddit_name, receiver, title, image_url: image_url)
                        elsif data["post_hint"].include? "link"
                            if data["url_overridden_by_dest"] != nil
                                url = data["url_overridden_by_dest"]
                                server.send_url(subreddit_name, receiver, title, url)
                            else
                                RedditPostHandler.log_error(data.to_json())
                            end
                        else
                            RedditPostHandler.log_error(data.to_json())
                        end
                    end
                elsif response.code == 404
                    server.send_message(subreddit_name, receiver, "", content: "Subreddit #{subreddit_name} does not exist and is no longer being followed")
                    receiver.unfollow(server_id, subreddit_name)
                else
                    server.send_message(subreddit_name, receiver, "", content: "Error #{response.code}. :(")
                end

            end
        end
    end
end