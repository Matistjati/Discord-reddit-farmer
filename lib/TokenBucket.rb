class TokenBucket
    attr_reader :max_token_count, :refill_time_in_seconds

    def initialize(max_tokens, refill_time)
        @max_token_count = max_tokens
        @refill_time_in_seconds = refill_time

        @tokens_used = 0
        @last_refill_time = Time.now
    end

    def time_to_next_refill()
        self.check_for_refill()
        return @refill_time_in_seconds - (Time.now - @last_refill_time)
    end

    def tokens_left()
        self.check_for_refill()
        return @max_token_count - @tokens_used
    end

    def request_allowed?
        self.check_for_refill()
        
        return @max_token_count - @tokens_used > 0
    end

    def request_sent()
        @tokens_used += 1
        return @max_token_count - @tokens_used
    end

    def check_for_refill()
        # Check if we should refill
        if (Time.now - @last_refill_time) > @refill_time_in_seconds
            self.refill_tokens()
        end
    end

    def refill_tokens()
        # Account for the time that passed after we should have refilled
        @last_refill_time = Time.now - (Time.now - @last_refill_time - @refill_time_in_seconds)
        @tokens_used = 0
    end
end