# sveda-ruby-sdk

Ruby SDK for the [Sveda](https://sveda.dev) sidecar HTTP API.

Docs: [sveda.dev/docs/hosts/ruby](https://sveda.dev/docs/hosts/ruby)

RubyGems: `sveda-ruby-sdk`

## Install

```ruby
gem "sveda-ruby-sdk"
```

```bash
gem install sveda-ruby-sdk
```

## Sidecar client

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
```

## Host integration (embed session + MCP tools)

`Sveda::Host::Server` mirrors the Laravel SDK: mint an embed token with `host_mcp_url` / `host_mcp_token`, and expose `POST /mcp/sveda` for the sidecar.

```ruby
server = Sveda::Host::Server.new(
  base_url: ENV["SVEDA_CLIENT_BASE_URL"],
  host_api_key: ENV["SVEDA_CLIENT_HOST_API_KEY"],
  mcp_url: ENV["SVEDA_CLIENT_MCP_URL"],
  server_name: "My App",
  instructions: "Tools for the current user."
)
server.resolve_tools_using { |user| [SearchPostsTool.new] }
server.policy_using { |_user| "agent" }

# Rails routes.rb
post "/sveda/session", to: "sveda_sessions#create"
match "/mcp/sveda", to: server.rack_app, via: :post

# SvedaSessionsController
render json: server.start_session(visitor_id: "user-#{current_user.id}")
```

Subclass `Sveda::Host::Tool` with `name`, `description`, `input_schema`, `mode`, `domain`, and `handle`.

By default, the server mints opaque MCP bearer tokens with `MemoryTokenStore`. Override with `mint_token_using` and `authenticate_using` for production auth.

Lower-level session minting:

```ruby
session = Sveda::Client.start_host_session(
  base_url: "https://sveda.example.com",
  host_api_key: host_key,
  visitor_id: "user-1",
  host_mcp_url: "https://app.example.com/mcp/sveda",
  host_mcp_token: mcp_token
)
```

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
