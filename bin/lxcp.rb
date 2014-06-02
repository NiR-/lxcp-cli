#!/usr/bin/env ruby

require 'English'
$LOAD_PATH.unshift File.dirname(__FILE__)

require './lxcp/cli.rb'
require './lxcp/exception.rb'

# LXCP need to be run with root privileges
if ENV['USER'] != "root"
  puts "You need to run \"" + ENV['_'] + " " + ARGV.join(' ') + "\" with root privileges. Use sudo/rvmsudo for this purpose."
  exit 1
end

begin
  LXCP::CLI.start(ARGV)
rescue LXCP::Exception => e
  puts e.message
end
