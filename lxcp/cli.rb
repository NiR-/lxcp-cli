require './lxcp/lxcp.rb'

module LXCP
  module CLI
    module_function

    def create(name, template=nil, ip=nil)
      container = LXCP::create(name, template, ip)

      if !container
        puts "Error during \"" + name + "\" creation."
      end
    end

    def list
      containers = LXCP::list

      for c in containers
        print c.name
        print " - "

        if c.running?
            print "RUNNING"
        else
            print "STOPPED"
        end

        print " - "
        print "IP: " + c.ip_addresses.join(', ')

        print "\n"
      end
    end
    
    def get_config(name=nil)
      unless name.nil?
        puts name + ": " + LXC::global_config_item(name)
      else
        [
          'lxc.default_config', 
          'lxc.lxcpath', 
          'lxc.bdev.lvm.vg', 
          'lxc.bdev.lvm.thin_pool', 
          'lxc.bdev.zfs.root'
        ].each { |item| get_config item }
      end
    end
    
    def set_config(name, value)
      
    end

    def version
      puts "LXCP Version: " + LXCP::version
      puts "LXC Version: " + LXC::version
    end
  end
end

