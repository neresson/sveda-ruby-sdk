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

      def mint(user_id: "anonymous")
        token = SecureRandom.hex(32)
        expires_at = Time.now + @ttl_seconds
        @mutex.synchronize do
          prune_locked
          @tokens[token] = { expires_at: expires_at, user_id: user_id.to_s }
        end
        token
      end

      def valid?(token)
        !lookup(token).nil?
      end

      def lookup(token)
        return nil if token.to_s.empty?

        @mutex.synchronize do
          prune_locked
          record = @tokens[token.to_s]
          return nil unless record && Time.now < record[:expires_at]

          { "id" => record[:user_id] }
        end
      end

      private

      def prune_locked
        now = Time.now
        @tokens.delete_if { |_token, record| record[:expires_at] <= now }
      end
    end
  end
end
