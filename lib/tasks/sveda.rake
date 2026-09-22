# frozen_string_literal: true

namespace :sveda do
  desc "Print the Sveda host tool manifest as JSON"
  task tools: :environment do
    host = Rails.application.config.x.sveda_host
    unless host
      warn "Sveda host is not configured (config.x.sveda_host)"
      exit 1
    end

    user = ENV["USER"] || ENV["SVEDA_USER"]
    subject = user ? host.describe(user) : host.describe
    puts JSON.pretty_generate(subject)
  end
end
