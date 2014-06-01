require './lxcp/container.rb'
require './lxcp/exception.rb'

module LXCP
  @@config = {
    :hosts_file => '/etc/hosts',
    :lxc_path   => LXC.global_config_item('lxc.lxcpath'),  
    
    :config_path  => '/etc/lxc/lxc.conf', 
    :config_items => [
      'lxc.default_config', 
      'lxc.lxcpath', 
      'lxc.bdev.lvm.vg', 
      'lxc.bdev.lvm.thin_pool', 
      'lxc.bdev.zfs.root'
    ], 
    
    :network => {
      # TODO: Need improves with IPAddr
      :address => '10.0.3',
      :name => 'lxcbr0',  
      :start_range => 20, 
      :stop_range => 254, 
      :dns => [ "213.186.33.99", "8.8.8.8", "8.8.4.4" ]
    }, 
    
    :domains => [ "$0", "$0.lxc" ]
  }

  module_function

  @version = "0.0.1"
  def version; return @version end

  def create name, template, ip=nil
    c = Container.new(name)

    unless !c.defined?
      raise "This container name is already in use."
    end
    
    ip = determine_ip if ip.nil?
    gateway = @@config[:network][:address] + ".1"
    domains = @@config[:domains].each { |v| v["$0"] = name  }
    
    c.create template
    
    # Configure container network
    c.set_config_item('lxc.network.ipv4', ip + "/24")
    c.set_config_item('lxc.network.ipv4.gateway', gateway)
    
    c.set_domains domains
    c.set_hostname domains.last
    
    add_ip_to_hosts_file ip, domains
    
    c.configure_network ip, gateway
    c.autostart!
    
    c.save_config
  end
  
  def pack name
    c = Container.new name
    c.freeze
    
    puts c.state.to_s
    puts c.running?.to_s
  end
  
  def destroy name
    c = Container.new name
    
    if !c.defined?
      raise "Container \"" + name + "\" does not exist."
    end
    
    if c.running?
      c.stop
    end
    
    remove_ip_from_hosts_file c.ip_addresses
    
    c.destroy
  end
  
  def start name
    c = Container.new name
    
    unless c.defined?
      raise "Container \"" + name + "\" does not exist."
    end
    
    unless c.running?
      c.start
    else
      raise "This container is already running."
    end
  end
  
  def stop name
    c = Container.new name
    
    unless c.defined?
      raise "Container \"" + name + "\" does not exist."
    end
    
    unless !c.running?
      c.stop
    else
      raise "This container is already stopped."
    end
  end
  
  def freeze name
    c = Container.new name
    
    unless c.defined?
      raise Exception, "Container \"" + name + "\" does not exist."
    end
    
    unless c.running?
      raise Exception, "Container \"" + name + "\" not running."
    else
      c.freeze
    end
  end
  
  def unfreeze name
    c = Container.new name
    
    unless c.defined?
      raise Exception, "Container \"" + name + "\" does not exist."
    end
    
    if !c.running?
      raise Exception, "Container \"" + name + "\" is not running."
    elsif c.state != :frozen
      raise Exception, "Container \"" + name + "\" is not frozen."
    else
      c.unfreeze
    end
  end
  
  def toggle_autostart name
    c = Container.new name
    
    unless c.defined?
      raise "Container \"" + name + "\" does not exist."
    end
    
    c.autostart! c.autostart?.to_i.zero?
  end

  def list
    containers = []

    for name in LXC::list_containers
      c = Container.new name
      containers << c
    end

    return containers
  end
  
  def determine_ip
    ip    = @@config[:network][:start_range]
    lines = File.readlines(@@config[:hosts_file]).find_all { |line| /^#{@@config[:network][:address]}/ =~ line }
    
    unless lines.empty?
      ip = lines.map { |v| v.split(' ').shift.split('.').pop }.max.to_i + 1
    end
    
    @@config[:network][:address] + "." + ip.to_s
  end
  
  def get_global_config name=nil
    unless name.nil?
      unless @@config[:config_items].include? name
        raise "This config item is not available. Available items: " + @@config[:config_items].join(', ')
      else
        puts name + ": " + LXC::global_config_item(name)
      end
    else
      @@config[:config_items].each { |item| get_global_config item }
    end
  end
  
  def set_global_config name, value
    unless @@config[:config_items].include? name
      raise "This config item is not available. Available items: " + @@config[:config_items].join(', ')
    else
      f = File.read(@@config[:config_path])
      val = name + ' = ' + value 
      
      if /^#{name}/ =~ f
        f = f.sub(/^#{name} = .*/, val)
      else
        f << val
      end
      
      File.write(@@config[:config_path], f)
    end
  end
  
  def add_ip_to_hosts_file ip, domains
    File.open("/etc/hosts", "a+") { |f| f << ip + "\t" + domains.join(' ') + "\n" }
  end
  
  def remove_ip_from_hosts_file ip
    if ip.is_a?(Array)
      ip.each { |v| remove_ip_from_hosts_file v }
    else
      f = File.readlines(@@config[:hosts_file])
      
      f.reject! do |item|
         /^#{ip}/ =~ item
      end
      
      File.write(@@config[:hosts_file], f.join)
    end
    
    def get_config item
      @@config[item]
    end
  end
end
