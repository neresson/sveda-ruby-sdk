# frozen_string_literal: true

require "securerandom"

module Sveda
  module Host
    class MemoryTokenStore
      def initialize(ttl_seconds: 3600)
        @ttl_seconds = ttl_seconds.positive? ? ttl_seconds : 3600
        @tokens = {}
        @mutex = Mutex.new
      end

      def mint
        token = SecureRandom.hex(32)
        expires_at = Time.now + @ttl_seconds
        @mutex.synchronize do
          prune_locked
          @tokens[token] = expires_at
        end
        token
      end

      def valid?(token)
        return false if token.to_s.empty?

        @mutex.synchronize do
          prune_locked
          expires_at = @tokens[token.to_s]
          expires_at && Time.now < expires_at
        end
      end

      private

      def prune_locked
        now = Time.now
        @tokens.delete_if { |_token, expires_at| expires_at <= now }
      end
    end
  end
end
