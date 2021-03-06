#!/usr/bin/env ruby

environment = ARGV[0]
ARGV[0] = nil

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../DeployGemfile', __FILE__)
load Gem.bin_path('bundler', 'bundle')

require 'aws-sdk'

# AWS.config(
#   access_key_id: ENV["#{environment.upcase}_AWS_ACCESS_KEY_ID"],
#   secret_access_key: ENV["#{environment.upcase}_AWS_SECRET_ACCESS_KEY"]
# )
AWS.config(
  access_key_id: ENV['AWS_ACCESS_KEY_ID'],
  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
)

config = {
  prod_build: {
    stack_id: '503b985f-d063-4bd6-a5ce-07c39376fc46',
    layer_id: 'dd207474-17c8-4309-8cf6-cbb07f457637',
    app_id: '38398e77-3795-48ee-bfe7-f4f0c271ee76'
  },
  dev: {
    stack_id: 'df8fcfa4-b4de-405c-b27b-b4d33508998d',
    layer_id: 'f15f5d55-4fe0-4ae0-80df-e34321b87f54',
    app_id: '020408de-90ab-4671-80a1-89c3549143b0'
  },
  dev2: {
    stack_id: '669edc07-0088-4a39-b359-d3209de1d74c',
    layer_id: 'bd7a54e9-ede0-4e31-bb43-485bb6949a02',
    app_id: '3bb55c8b-fd79-41d4-be97-0091201813fe'
  }
}

client = AWS::OpsWorks::Client.new

nodes = client.describe_instances(
  layer_id: config[environment.to_sym][:layer_id]
)
instance_array = []
nodes[:instances].map { |val, _| instance_array << val[:instance_id] }

deployment = client.create_deployment(
  app_id: config[environment.to_sym][:app_id],
  stack_id: config[environment.to_sym][:stack_id],
  instance_ids: instance_array,
  command: {
    name: 'deploy'
  },
  comment: "Deploying build from circleci: #{ENV['CIRCLE_BUILD_NUM']} sha: #{ENV['CIRCLE_SHA1']} #{ENV['CIRCLE_COMPARE_URL']}"
)

timeout = 60 * 5
time_start = Time.now.utc
success = false

process = ['\\', '|', '/', '-']
i = 0
until success
  desc = client.describe_deployments(deployment_ids: [deployment[:deployment_id]])
  success = desc[:deployments][0][:status] == 'successful'
  time_passed = Time.now.utc - time_start
  if i >= process.length - 1
    i = 0
  else
    i += 1
  end
  print "\r"
  print "Deploying: #{process[i]} status: #{desc[:deployments][0][:status]} timeout: #{timeout} -- time passed: #{time_passed}"
  exit 1 if timeout < time_passed
  sleep 4
end

exit 0
