require 'httparty'
require_relative "ContentProvider"
require_relative "RedditPostHandler"
require_relative "TokenBucket"

class RedditWatcher
    include ContentProvider

    def initialize(receiver, bucket=TokenBucket)
        @receiver = receiver
        @bucket = bucket.new(60, 60)

        refresh_token()
    end

    def check_for_posts(options, post_getter=RedditPostHandler)
        post_getter.check_and_send_posts(self, options, @receiver, @bucket)
        @receiver.save_state()
    end

    def self.get_generic_header()
        return {"Authorization": "bearer #{@token}", "User-Agent" => RedditWatcher.get_user_agent()}
    end

    def self.get_user_agent()
        return "Windows; Reddit scraper 0.2 by u/PreciousFish69"
    end

    def refresh_token()
        @token = get_access_token()
    end

    def get_access_token()
        
        # Only load in credentials as local variables so that they do not remain in memory for too long
        # One improvement would be to manually trigger a garbage collection at the end of the function
        # This could be further improved with some level of encryption, although I know far too little about that area to make something secure
        path = 'data/reddit_credentials.json'
        if not File.exists?(path)
            puts("No credentials file found. Will now abort.")
            exit()
        end
        credentials = File.read(path)
        json = JSON.parse(credentials)

        app_token = json["token"]
        app_secret = json["secret"]
        username = json["username"]
        password = json["password"]

        auth = {username: app_token, password: app_secret}

        body = {grant_type: "password", username: username, password: password}

        headers = {"User-Agent" => RedditWatcher.get_user_agent()}

        response = HTTParty.post('https://www.reddit.com/api/v1/access_token', basic_auth: auth, body: body, headers: headers)
    end

    def self.get_request_link(subreddit, timeframe, listing:"top", count:100)
        return "https://www.reddit.com/r/#{subreddit}/#{listing}.json?limit=#{count}&t=#{timeframe}"
    end
end