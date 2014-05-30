#!/usr/bin/env ruby

require 'rubygems'
require 'cli'
require 'lxc'
require './lxcp/cli.rb'

if ENV['USER'] != "root"
  print "You need to run \"" + ENV['_'] + " " + ARGV.join(' ') + "\" with root privileges. Use sudo for this purpose.\n\n"
  exit 1
end

cli = CLI.new do
  description 'LXC Panel CLI Tools'

  # Actions
  option :create, :description => 'Create a container'
  option :pack,   :description => 'Pack a container'
  option :deploy, :description => 'Deploy a container'
  option :remove, :description => 'Remove a container'
  option :list,   :description => 'List all containers'
  option :config, :description => 'Gets/Sets container (or global) configuration'
  option :version, :short => :v, :description => 'LXCP & LXC versions'
  
  # Production mode switch
  switch :prod, :description => 'Production mode (for create/deploy)'
  
  switch :value,        :required => false, :description => 'Configuration item value'

  # Arguments
  argument :name,       :required => false, :description => 'Container name (or item name for "config")'
  argument :template,   :default  => "debian", :required => false, :description => 'Archive template name'
  argument :ip_address, :required => false, :description => "IP addresses (seperated by ',')" 
end
settings = cli.parse!

if settings.create
  name         = settings.name
  template     = settings.template
  ip_addresses = settings.ip_address.split(',') if !settings.ip_address.nil?

  if name.nil?
    cli.usage!
    exit 1
  end

  LXCP::CLI::create name, template, ip_addresses
elsif settings.list
  LXCP::CLI::list
elsif settings.config
  puts settings
  exit 1
  
  unless settings.val.nil?
    LXCP::CLI::set_config settings.name settings.val
  else
    LXCP::CLI::get_config settings.name
  end
elsif settings.ver
  LXCP::CLI::version
else
  cli.usage!
end
