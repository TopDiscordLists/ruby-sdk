# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

# Official Top Discord List SDK for Ruby.
module TopDiscordList
  DEFAULT_BASE_URL = "https://topdiscordlist.com/api"
  SIGNATURE_HEADER = "X-TDL-Signature"
  EVENT_HEADER = "X-TDL-Event"
  DEFAULT_TOLERANCE_SECONDS = 300

  class Error < StandardError
    attr_reader :status

    def initialize(message, status = nil)
      super(message)
      @status = status
    end
  end

  module_function

  def sign(secret, timestamp, raw_body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
  end

  def parse_signature_header(header)
    return nil if header.nil? || header.empty?

    parts = {}
    header.split(",").each do |chunk|
      key, _, value = chunk.partition("=")
      parts[key.strip] = value.strip unless value.empty?
    end

    timestamp = Integer(parts["t"], exception: false)
    signature = parts["v1"]
    return nil if timestamp.nil? || signature.nil?

    [timestamp, signature]
  end

  def verify_signature(secret, header, raw_body, tolerance_seconds: DEFAULT_TOLERANCE_SECONDS, now: nil)
    parsed = parse_signature_header(header)
    return false if parsed.nil?

    timestamp, provided = parsed
    current = now || Time.now.to_i
    return false if tolerance_seconds.positive? && (current - timestamp).abs > tolerance_seconds

    expected = sign(secret, timestamp, raw_body.to_s)
    OpenSSL.secure_compare(expected, provided)
  end

  # HTTP client for the developer API.
  class Client
    def initialize(token, base_url: DEFAULT_BASE_URL, timeout: 10)
      raise Error, "A listing token is required" if token.nil? || token.empty?

      @token = token
      @base_url = base_url.sub(%r{/+\z}, "")
      @timeout = timeout
    end

    def listing
      request("/v1/listing")
    end

    def has_voted(discord_id)
      request("/v1/votes/check?#{URI.encode_www_form('discordId' => discord_id)}")
    end

    def has_voted_by_user_id(user_id)
      request("/v1/votes/check?#{URI.encode_www_form('userId' => user_id)}")
    end

    def votes(limit: 50, page: 1)
      request("/v1/votes?#{URI.encode_www_form(limit: limit, page: page)}")
    end

    def analytics(days: 7)
      request("/v1/analytics?#{URI.encode_www_form(days: days)}")
    end

    def post_stats(slug, server_count:, user_count: nil, shard_count: nil)
      body = { serverCount: server_count }
      body[:userCount] = user_count unless user_count.nil?
      body[:shardCount] = shard_count unless shard_count.nil?
      request("/bots/#{URI.encode_www_form_component(slug)}/stats", method: :post, body: body)
    end

    private

    def request(path, method: :get, body: nil)
      uri = URI.parse("#{@base_url}#{path}")
      klass = method == :post ? Net::HTTP::Post : Net::HTTP::Get
      req = klass.new(uri)
      req["Authorization"] = "Bot #{@token}"
      req["Accept"] = "application/json"
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end

      response = Net::HTTP.start(
        uri.hostname, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @timeout, read_timeout: @timeout
      ) { |http| http.request(req) }

      parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      unless response.is_a?(Net::HTTPSuccess)
        raise Error.new(parsed["error"] || response.message, response.code.to_i)
      end

      parsed
    rescue JSON::ParserError
      raise Error, "Top Discord List returned an unreadable response"
    end
  end
end
