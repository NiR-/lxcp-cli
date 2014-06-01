#!/usr/bin/env ruby

require 'English'
$LOAD_PATH.unshift File.dirname(__FILE__)

require './lxcp/cli.rb'

# LXCP need to be run with root privileges
if ENV['USER'] != "root"
  puts "You need to run \"" + ENV['_'] + " " + ARGV.join(' ') + "\" with root privileges. Use sudo/rvmsudo for this purpose."
  exit 1
end

LXCP::CLI.start(ARGV)
