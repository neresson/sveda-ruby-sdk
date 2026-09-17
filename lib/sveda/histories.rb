# frozen_string_literal: true

require "uri"

module Sveda
  class Histories
    def initialize(transport)
      @transport = transport
    end

    def list
      @transport.request_json("GET", "/sveda/chat-histories")
    end

    def get(chat_id)
      @transport.request_json("GET", history_path(chat_id))
    end

    def rename(chat_id, title)
      @transport.request_json("PATCH", history_path(chat_id), { "title" => title })
    end

    def delete(chat_id)
      @transport.request_json("DELETE", history_path(chat_id))
    end

    private

    def history_path(chat_id)
      "/sveda/chat-histories/#{URI.encode_uri_component(chat_id.to_s)}"
    end
  end
end
