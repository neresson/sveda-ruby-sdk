# frozen_string_literal: true

module Sveda
  class Message
    attr_reader :payload

    def initialize(payload)
      @payload = payload
    end

    def explanation
      payload["explanation"].to_s
    end

    def tokens_used
      payload["tokens_used"].to_i
    end

    def chat_id
      payload["chat_id"].to_s
    end

    def self.from_payload(payload)
      new(payload)
    end
  end
end
