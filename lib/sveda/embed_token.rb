# frozen_string_literal: true

module Sveda
  class EmbedToken
    attr_reader :token, :visitor_id, :expires_in, :appearance

    def initialize(token:, visitor_id:, expires_in:, appearance: nil)
      @token = token
      @visitor_id = visitor_id
      @expires_in = expires_in
      @appearance = appearance
    end

    def self.from_payload(payload)
      appearance = payload["appearance"]
      appearance = nil unless appearance.is_a?(Hash)

      new(
        token: payload["token"].to_s,
        visitor_id: payload["visitor_id"].to_s,
        expires_in: [payload.fetch("expires_in", 3600).to_i, 60].max,
        appearance: appearance
      )
    end
  end
end
