#!/usr/bin/env ruby

require 'aws/ec2'
require 'csv'

usage = {}

client = AWS::EC2::Client.new(
    region: ARGV[0] || raise("Usage: #{File.basename($0)} aws_region (e.g. ap-southeast-1)"),
    access_key_id: ENV['AWS_ACCESS_KEY_ID'] || raise('AWS_ACCESS_KEY_ID not set'),
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'] || raise('AWS_SECRET_ACCESS_KEY not set')
)

client.describe_reserved_instances[:reserved_instances_set].each do |reservation|
  next if reservation[:end] < Time.now

  type = reservation[:instance_type]
  zone = reservation[:availability_zone]
  count = reservation[:instance_count]

  usage[type] ||= {}
  usage[type][zone] ||= {}
  usage[type][zone][:reserved] ||= 0
  usage[type][zone][:reserved] += count
end

client.describe_instances[:reservation_set].each do |reservation|
  reservation[:instances_set].each do |instance|
    zone = instance[:placement][:availability_zone]
    type = instance[:instance_type]

    usage[type] ||= {}
    usage[type][zone] ||= {}
    usage[type][zone][:used] ||= 0
    usage[type][zone][:used] += 1
  end
end

output = CSV.generate do |csv|
  csv << %w[instance_type zone number_used number_reserved spare_reservations]
  usage.sort{|a, b| a[0] <=> b[0]}.each do |type, zone_data|
    zone_data.sort{|a, b| a[0] <=> b[0]}.each do |zone, data|
      used = data[:used] || 0
      reserved = data[:reserved] || 0
      csv << [type, zone, used, reserved, reserved - used]
    end
  end
end

puts output
