# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "top_discord_list"
  spec.version = "1.0.0"
  spec.summary = "Official Top Discord List SDK"
  spec.description = "Vote webhooks, live vote stream, and developer API for Top Discord List."
  spec.authors = ["Top Discord List"]
  spec.license = "MIT"
  spec.homepage = "https://topdiscordlist.com/developers"
  spec.files = Dir["lib/**/*.rb"] + ["README.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => "https://topdiscordlist.com/developers",
    "source_code_uri" => "https://github.com/TopDiscordLists/ruby-sdk",
    "bug_tracker_uri" => "https://github.com/TopDiscordLists/ruby-sdk/issues",
    "rubygems_mfa_required" => "true"
  }
end
