require './lxcp/container.rb'
require './lxcp/exception.rb'

module LXCP
  @@config = {
    :hosts_file => '/etc/hosts',
    :lxc_path   => LXC.global_config_item('lxc.lxcpath'),  
    :temp_path  => '/tmp', 
    
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

  @version = "0.1"
  def version; return @version end

  def create name, template, ip=nil
    c = Container.new name

    unless !c.defined?
      raise Exception, "This container name is already in use."
    end
    
    c.create template
    configure name, ip
    
    return c
  end
  
  def pack name, dest=nil
    c = Container.new name
    path = @@config[:lxc_path] + '/' + name
    
    if !c.defined?
      raise Exception, "Container \"" + name + "\" does not exist."
    end
    
    if c.running? && !c.frozen?
      c.freeze
    end
    
    dest ||= @@config[:lxc_path] + "/lxcp-" + name + ".tgz"
    
    system 'tar zcf ' + dest + ' -C ' + path + ' ./ 2>&1'
    unless $?.success?
      raise Exception, "Error during packing."
    end
    
    c.unfreeze
    
    dest
  end
  
  def deploy template, name=nil
    temp_name = "lxcp-" + Time.now.getutc.to_i.to_s
    temp_path = @@config[:temp_path] + "/" + temp_name
    
    Dir.mkdir temp_path
    system 'tar zxf ' + template + ' -C ' + temp_path
    
    begin
      unless $?.success?
        raise Exception, "Error during unpacking."
      end
      
      if name.nil?
        c = LXCP::Container.new temp_name, @@config[:temp_path]
        name = c.config_item "lxc.utsname"
      end
      
      final_path = @@config[:lxc_path] + "/" + name
      
      if Dir.exists? final_path
        raise Exception, "This name (\"" + name + "\") is already in use. You need to provide your own container name if you want to deploy it."
      end
      
      FileUtils.mv temp_path, final_path
      
      configure name
    ensure
      if Dir.exists? temp_path
        FileUtils.rmtree temp_path
      end
    end
  end
  
  def destroy name
    c = Container.new name
    
    if !c.defined?
      raise "Container \"" + name + "\" does not exist."
    end
    
    unless c.stopped?
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
    
    unless c.stopped?
      raise "This container is already running."
    end
    
    c.start
  end
  
  def stop name
    c = Container.new name
    
    unless c.defined?
      raise "Container \"" + name + "\" does not exist."
    end
    
    unless c.running?
      raise "This container is already stopped."
    end
    
    c.stop
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
    
    unless c.running?
      raise Exception, "Container \"" + name + "\" is not running."
    end
    
    unless c.frozen?
      raise Exception, "Container \"" + name + "\" is not frozen."
    end
    
    c.unfreeze
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
  
  def configure name, ip=nil
    ip ||= determine_ip
    gateway = @@config[:network][:address] + ".1"
    domains = @@config[:domains].each { |v| v["$0"] = name }
    
    c = LXCP::Container.new name
    c.set_config_item 'lxc.utsname', name
    
    c.configure_network ip, gateway
    add_ip_to_hosts_file ip, domains
    
    c.set_domains domains
    c.set_hostname domains.last
    
    return c
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
      ip.each { |val| remove_ip_from_hosts_file val }
    else
      f = File.readlines(@@config[:hosts_file])
      
      f.reject! { |line| /^#{ip}/ =~ line }
      
      File.write(@@config[:hosts_file], f.join)
    end
    
    def get_config item
      @@config[item]
    end
  end
end
