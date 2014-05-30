require 'lxc'

module LXCP
  @version = "0.0.1"

  module_function

  def version; return @version end

  def create(name, template=nil, ip=nil)
    c = Container.new(name)

    if c.defined?
      raise "This container name is already in use."
    end
    
    # c.create
  end

  def list
    containers = []

    for c in LXC::list_containers
      containers << Container.new(c)
    end

    return containers
  end

  class Container < LXC::Container
    def configured_ip_addresses
      File.foreach(self.config_file_name).find_all do |line|
        /^lxc\.network\.ip/ =~ line
      end.map { |line| line.split('=').pop.strip.split('/').shift }
    end

    def ip_addresses
      if !self.running?
        configured_ip_addresses
      else
        self.superclass.ip_addresses
      end
    end
  end
end
