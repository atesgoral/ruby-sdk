# frozen_string_literal: true

require "test_helper"
require "open3"

module MCP
  class LoggingDocumentationTest < ActiveSupport::TestCase
    include InitializeParamsTestHelper

    test "logging example honors the client's configured level" do
      documentation = File.read(File.expand_path("../../docs/_server/logging.md", __dir__))
      script = documentation[/```ruby\n(.*?)```/m, 1]
      refute_nil script

      requests = [
        { jsonrpc: "2.0", id: 1, method: "initialize", params: initialize_params(protocolVersion: "2025-11-25") },
        { jsonrpc: "2.0", method: "notifications/initialized" },
        { jsonrpc: "2.0", id: 2, method: "logging/setLevel", params: { level: "error" } },
        { jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "log_messages", arguments: {} } },
      ]
      input = requests.map { |request| JSON.generate(request) }.join("\n") + "\n"
      lib = File.expand_path("../../lib", __dir__)
      stdout, stderr, status = Open3.capture3(
        { "RUBYOPT" => nil }, RbConfig.ruby, "-I", lib, "-r", "mcp", "-e", script, stdin_data: input,
      )
      assert_predicate status, :success?, stderr

      messages = stdout.lines.map { |line| JSON.parse(line) }
      logs = messages.select { |message| message["method"] == "notifications/message" }
      assert_equal ["error"], logs.map { |message| message["params"]["level"] }
      assert_equal "DatabaseLogger", logs.first["params"]["logger"]
      assert_equal [1, 2, 3], messages.select { |message| message.key?("id") }.map { |message| message["id"] }
      response = messages.find { |message| message["id"] == 3 }
      assert_equal "ok", response["result"]["content"].first["text"]
    end
  end
end
