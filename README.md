# sveda-ruby-sdk

Ruby SDK for the [Sveda AI](https://github.com/neresson/sveda) sidecar HTTP API.

RubyGems: `sveda-ruby-sdk`

## Install

```ruby
gem "sveda-ruby-sdk"
```

```bash
gem install sveda-ruby-sdk
```

## Usage

```ruby
require "sveda"

client = Sveda::Client.new(base_url: "https://sveda.example.com", host_api_key: host_key)
token = client.embed.create_token(visitor_id: "user-1")

client = Sveda::Client.new(base_url: "https://sveda.example.com", embed_token: token.token)
client.chat.create_streamed(
  messages: [{ role: "user", content: "Hello" }],
  chatId: "chat-1"
) do |event|
  puts event.type
end

session = Sveda::Client.start_host_session(
  base_url: "https://sveda.example.com",
  host_api_key: host_key,
  visitor_id: "user-1"
)
```

## License

MIT
