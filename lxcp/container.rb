require 'lxc'

module LXCP
  class Container < LXC::Container
    def ip_addresses
      unless self.running?
        configured_ip_addresses
      else
        super
      end
    end
    
    def configured_ip_addresses
      addresses = {ipv4: [], ipv6: []}
      i = 0
      
      begin
        until keys('lxc.network.' + i.to_s).empty?
          ipv4 = config_item('lxc.network.' + i.to_s + '.ipv4')
          unless ipv4.empty? || ipv4.first.empty?
            addresses[:ipv4] << ipv4.first
          end
          
          ipv6 = config_item('lxc.network.' + i.to_s + '.ipv6')
          unless ipv6.empty? || ipv6.first.empty?
            addresses[:ipv6] << ipv6.first
          end
          
          i += 1
        end
      rescue LXC::Error
      end

      addresses[:ipv4].concat(addresses[:ipv6])
    end

    def autostart?
      config_item("lxc.start.auto")
    end
    
    def autostart! auto=true
      set_config_item('lxc.start.auto', (auto ? "1" : "0"))
      save_config
      auto
    end
    
    def set_domains domains
      File.open(rootfs + "/etc/hosts", "a+") { |f| f << "127.0.0.1\t" + domains.join(' ') }
    end
    
    def set_hostname hostname
      File.write(rootfs + "/etc/hostname", hostname)
    end
    
    def rootfs
      config_item 'lxc.rootfs'
    end
    
    def configure_network ip, gateway
      File.write(rootfs + "/etc/network/interfaces", <<END
auto lo
iface lo inet loopback
 
auto eth0
iface eth0 inet static
    address #{ip}
    netmask 255.255.255.0
    gateway #{gateway}
END
)
    end
  end
end
