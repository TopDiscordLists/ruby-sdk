# top_discord_list

Hand out rewards when someone votes for your Discord server or bot on
[Top Discord List](https://topdiscordlist.com).

```bash
gem install top_discord_list
```

> **Not on RubyGems yet.** The first release is still to come. Until then, in
> your `Gemfile`:
>
> ```ruby
> gem "top_discord_list", git: "https://github.com/TopDiscordLists/ruby-sdk"
> ```

```ruby
require "top_discord_list"

halt 401 unless TopDiscordList.verify_signature(secret, signature_header, raw_body)
```

Ruby 3.0 or newer, standard library only. No gems get pulled in behind it.

## How votes reach you

We POST a signed JSON body to a URL you set under **Vote rewards** on your
listing. If your server is down we retry after 1, 5, 15, 60, and 180 minutes,
six attempts in total, so a deploy does not lose a vote.

There is also a WebSocket vote stream for instant delivery without a public URL.
This gem does not wrap it, since Ruby has no WebSocket client in the standard
library and this gem is deliberately dependency free. If you want it, point
[async-websocket](https://rubygems.org/gems/async-websocket) or
[faye-websocket](https://rubygems.org/gems/faye-websocket) at
`wss://topdiscordlist.com/api/v1/events/votes` with an
`Authorization: Bot YOUR_TOKEN` header. The frame format is in the
[API reference](https://github.com/TopDiscordLists/api-docs).

## Getting a token

Open your listing, hit **Edit listing**, scroll to **Developer integrations**,
and generate a listing token. It is shown once, so put it straight into an
environment variable.

There are two secrets and they do different jobs. The **listing token**
authenticates you to us, for the API. The **webhook secret** authenticates us to
you, so you can tell a real delivery from someone who guessed your URL.
Rotating one does not affect the other.

## Verifying a webhook

Sinatra:

```ruby
post "/vote" do
  raw = request.body.read
  signature = request.env["HTTP_X_TDL_SIGNATURE"]

  halt 401 unless TopDiscordList.verify_signature(SECRET, signature, raw)

  payload = JSON.parse(raw)
  give_reward(payload["user"]["discordId"]) unless payload["vote"]["isTest"]
  status 200
end
```

Rails, where you need to skip the CSRF check and read the body yourself:

```ruby
class VotesController < ActionController::API
  def create
    raw = request.raw_post
    signature = request.headers["X-TDL-Signature"]

    return head :unauthorized unless TopDiscordList.verify_signature(SECRET, signature, raw)

    payload = JSON.parse(raw)
    GiveRewardJob.perform_later(payload["user"]["discordId"]) unless payload["vote"]["isTest"]
    head :ok
  end
end
```

Read the raw body before anything parses it. `JSON.parse` followed by
`to_json` changes key order and whitespace, and the signature stops matching.
That is the single most common thing people get wrong.

Reply 200 quickly and do the reward in a background job. If you hold the request
open while you work and we time out, you get a retry for work you already did.

`verify_signature` also rejects anything more than 300 seconds old, so a
captured delivery cannot be replayed at you forever. Pass
`tolerance_seconds: 0` only when replaying a stored delivery in a test.

## Test events

A test delivery is identical to a real one except `event` is `"test"` and
`payload["vote"]["isTest"]` is `true`. Branch on it, or you will hand yourself
free rewards every time you press the button.

## Calling the API

```ruby
client = TopDiscordList::Client.new(ENV["TDL_TOKEN"])

client.listing
client.has_voted("123456789012345678")
client.has_voted_by_user_id("user_abc")
client.votes(limit: 50, page: 1)
client.post_stats("my-bot", server_count: 1200, shard_count: 4)
```

`has_voted` already accounts for the 24 hour cooldown, so you can use `"voted"`
directly. It also returns `"expiresAt"`, which is handy for a "come back in 6
hours" message.

A non 2xx response raises `TopDiscordList::Error`, which carries `#status` so
you can tell a revoked token (403) from a rate limit (429).

## Links

- [Developer docs](https://topdiscordlist.com/developers)
- [Raw HTTP and WebSocket reference](https://github.com/TopDiscordLists/api-docs)
- [SDKs in other languages](https://github.com/TopDiscordLists)

## Contributing

`ruby conformance/run.rb` checks this gem against
[the shared signature vectors](test-vectors.json), the same eight cases every
other language SDK has to pass. CI runs it on every push. If the signature logic
breaks, people quietly stop receiving votes, which is why that gate exists.

MIT licensed.
