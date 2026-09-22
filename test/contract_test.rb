# frozen_string_literal: true

require "json"
require "test_helper"

class ContractTest < Minitest::Test
  def test_sidecar_contract_surface
    path = File.expand_path("../contracts/sidecar.v1.json", __dir__)
    path = File.expand_path("../../sveda/packages/protocol/contracts/sidecar.v1.json", __dir__) unless File.exist?(path)
    contract = JSON.parse(File.read(path))
    assert_equal "1.0", contract["version"]
    assert_equal "/sveda", contract["prefix"]
    assert_equal "application/vnd.sveda.stream+json", contract.dig("accept", "svedaStream")
    routes = contract["routes"].map { |route| "#{route['method']} #{route['path']}" }
    assert_includes routes, "POST /sveda/stream"
    assert_includes routes, "POST /sveda/message"
    assert_includes routes, "POST /sveda/embed/token"
  end
end
