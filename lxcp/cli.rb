require 'thor'
require './lxcp/lxcp.rb'

module LXCP
  class CLI < Thor
    package_name "lxcp"
    
    desc "create [-p|--prod] <name> [<ip> [<port>]] [-t <template>|--template <template>]", "Create a new container and configure host/container."
    option :prod, :type => :boolean, :aliases => "p"
    option :template, :default => "debian", :aliases => "t"
    def create name, ip=nil, port=80
      template = options[:template]
      
      begin
        c = LXCP::create name, template, ip
        c.load_config # Why ?!?!?! (we have just saved it !)
        
        puts "Container IP : " + c.ip_addresses.join(', ')
      rescue LXCP::Exception => e
        puts e.message
      end
    end
    
    desc "pack <name>", "Create an archive from an existing container. Will need to freeze the container."
    def pack name
      begin
        path = LXCP::pack name
        size = human_readable_size File.size(path)
        
        puts "Container has been packed to \"" + path + "\" (" + size + ")."
      rescue LXCP::Exception => e
        puts e.message
      end
    end
    
    desc "deploy [-p] [<name>] <template>", "Deploy a container from a previously created archive. Will (re)configure the host/container."
    option :prod, :type => :boolean, :aliases => "p"
    def deploy name=nil, template
      begin
        LXCP::deploy template, name
        
        puts "Container has been deployed."
      rescue LXCP::Exception => e
        puts e.message
      end
    end
    
    desc "destroy <name>", "Destroy a container"
    def destroy name
      LXCP::destroy(name)
    
      puts "Container successfully deleted."
    end
    
    desc "start <name>", "Start the given container"
    def start name
      c = LXCP::start name
      
      if c
        puts "Container started. IP: " + c.ip_addresses.join(', ')
      end
    end
    
    desc "stop <name>", "Stop the given container"
    def stop name
      c = LXCP::stop name
      
      if c
        puts "Container stopped."
      end
    end
    
    desc "freeze <name>", "Freeze the container."
    def freeze name
      begin
        LXCP::freeze name
        puts "The container has been frozen."
      rescue LXCP::Exception => e
        puts e.message
      end
    end
    
    desc "unfreeze <name>", "Unfreeze the container."
    def unfreeze name
      begin
        LXCP::unfreeze name
        puts "The container has been unfrozen."
      rescue LXCP::Exception => e
        puts e.message
      end
    end
    
    desc "autostart <name>", "Toggle the autostart flag"
    def autostart name
      puts "Autostart flag " + (LXCP::toggle_autostart(name) ? "added" : "deleted") + "."
    end

    desc "list", "List all containers"
    def list
      containers = LXCP::list

      for c in containers
        print c.name + " - " + c.state.to_s + " - "
        print "IP: " + c.ip_addresses.join(', ')
        print " - Autostart flag " + (c.autostart? ? "set" : "not set")
        print "\n"
      end
    end
    
    desc "config [<name> [<value>]]", "Get/Set global configuration"
    def config name=nil, value=nil
      unless name.nil? || value.nil?
        LXCP::set_global_config name, value
      else
        LXCP::get_global_config name
      end
    end
    
    desc "version", "Show LXC & LXCP versions"
    def version
      puts "LXCP Version: " + LXCP::version
      puts "LXC Version: " + LXC::version
    end
    
    no_commands {
      def human_readable_size size
        if size >= 1 << 30
          size = (size / (1 << 30)).round(2).to_s + " GB"
        elsif size >= 1 << 20
          size = (size / (1 << 20)).round(2).to_s + " MB"
        elsif size >= 1 << 10
          size = (size / (1 << 10)).round(2).to_s + " KB"
        else
          size = size.to_s + " bytes"
        end
      end
    }
  end
end
