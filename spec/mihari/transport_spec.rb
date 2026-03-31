# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mihari::Transport do
  let(:token) { "test-token-abc123" }
  let(:endpoint) { "https://logs.mihari.dev" }
  let(:response_body) { '{"status":"accepted","count":1}' }

  let(:transport) do
    described_class.new(
      token: token,
      endpoint: endpoint,
      batch_size: 5,
      flush_interval: 999,
      max_retries: 2
    )
  end

  before do
    stub_request(:post, "#{endpoint}/logs")
      .to_return(status: 202, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  after do
    transport.shutdown
  end

  describe "#enqueue" do
    it "adds a log entry to the queue" do
      entry = Mihari::LogEntry.new(level: "info", message: "test")
      transport.enqueue(entry)

      expect(transport.queue_size).to eq(1)
    end

    it "does not enqueue after shutdown" do
      transport.shutdown
      entry = Mihari::LogEntry.new(level: "info", message: "test")
      transport.enqueue(entry)

      expect(transport.queue_size).to eq(0)
    end

    it "auto-sends when batch size is reached" do
      5.times do |i|
        entry = Mihari::LogEntry.new(level: "info", message: "msg #{i}")
        transport.enqueue(entry)
      end

      sleep(0.1)
      expect(transport.queue_size).to eq(0)
      expect(a_request(:post, "#{endpoint}/logs")).to have_been_made
    end
  end

  describe "#flush" do
    it "sends all queued entries" do
      3.times do |i|
        entry = Mihari::LogEntry.new(level: "info", message: "msg #{i}")
        transport.enqueue(entry)
      end

      transport.flush

      expect(transport.queue_size).to eq(0)
      expect(a_request(:post, "#{endpoint}/logs")).to have_been_made
    end

    it "does nothing when queue is empty" do
      transport.flush
      expect(a_request(:post, "#{endpoint}/logs")).not_to have_been_made
    end
  end

  describe "gzip compression" do
    it "sends gzip-compressed request body" do
      entry = Mihari::LogEntry.new(level: "info", message: "compressed log")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with(headers: { "Content-Encoding" => "gzip" }))
        .to have_been_made
    end

    it "sends valid gzip data" do
      entry = Mihari::LogEntry.new(level: "info", message: "gzip test")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with { |req|
          io = StringIO.new(req.body)
          gz = Zlib::GzipReader.new(io)
          data = gz.read
          gz.close
          entries = JSON.parse(data)
          entries.is_a?(Array) && entries.first["message"] == "gzip test"
        }).to have_been_made
    end
  end

  describe "deflate compression" do
    let(:transport) do
      described_class.new(
        token: token,
        endpoint: endpoint,
        batch_size: 5,
        flush_interval: 999,
        compression: :deflate
      )
    end

    it "sends deflate-compressed request body" do
      entry = Mihari::LogEntry.new(level: "info", message: "deflate log")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with(headers: { "Content-Encoding" => "deflate" }))
        .to have_been_made
    end
  end

  describe "authentication" do
    it "sends Bearer token in Authorization header" do
      entry = Mihari::LogEntry.new(level: "info", message: "auth test")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with(headers: { "Authorization" => "Bearer #{token}" }))
        .to have_been_made
    end
  end

  describe "retry logic" do
    before do
      WebMock.reset!
      stub_request(:post, "#{endpoint}/logs")
        .to_return(status: 500, body: "Internal Server Error")
        .then.to_return(status: 202, body: response_body)
    end

    it "retries on server errors" do
      entry = Mihari::LogEntry.new(level: "info", message: "retry test")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")).to have_been_made.at_least_once
    end
  end

  describe "connection errors" do
    before do
      WebMock.reset!
      stub_request(:post, "#{endpoint}/logs")
        .to_raise(Errno::ECONNREFUSED)
    end

    it "handles connection refused gracefully" do
      entry = Mihari::LogEntry.new(level: "info", message: "conn test")
      transport.enqueue(entry)

      expect { transport.flush }.not_to raise_error
    end
  end

  describe "#shutdown" do
    it "flushes remaining entries on shutdown" do
      2.times do |i|
        entry = Mihari::LogEntry.new(level: "info", message: "shutdown msg #{i}")
        transport.enqueue(entry)
      end

      transport.shutdown

      expect(a_request(:post, "#{endpoint}/logs")).to have_been_made
    end
  end

  describe "content type" do
    it "sends application/json content type" do
      entry = Mihari::LogEntry.new(level: "info", message: "content type test")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with(headers: { "Content-Type" => "application/json" }))
        .to have_been_made
    end
  end

  describe "user agent" do
    it "sends mihari-ruby user agent" do
      entry = Mihari::LogEntry.new(level: "info", message: "ua test")
      transport.enqueue(entry)
      transport.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with(headers: { "User-Agent" => "mihari-ruby/#{Mihari::VERSION}" }))
        .to have_been_made
    end
  end
end
