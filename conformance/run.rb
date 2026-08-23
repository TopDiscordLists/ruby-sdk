require "json"
require_relative "../lib/top_discord_list"

root = File.expand_path("..", __dir__)
v = JSON.parse(File.read(File.join(root, "test-vectors.json")))
now = v["timestamp"]

puts JSON.generate({
  invalidSig: TopDiscordList.verify_signature(v["secret"], v["invalidSignatureHeader"], v["body"], now: now),
  malformed: TopDiscordList.verify_signature(v["secret"], "garbage", v["body"], now: now),
  staleAcceptedNoTolerance: TopDiscordList.verify_signature(v["secret"], v["staleButValidHeader"], v["body"], tolerance_seconds: 0, now: now),
  staleRejected: TopDiscordList.verify_signature(v["secret"], v["staleButValidHeader"], v["body"], now: now),
  staleTs: TopDiscordList.verify_signature(v["secret"], v["staleTimestampHeader"], v["body"], now: now),
  tamperedBody: TopDiscordList.verify_signature(v["secret"], v["signatureHeader"], v["body"] + " ", now: now),
  valid: TopDiscordList.verify_signature(v["secret"], v["signatureHeader"], v["body"], now: now),
  wrongSecret: TopDiscordList.verify_signature("whsec_wrong", v["signatureHeader"], v["body"], now: now),
})
