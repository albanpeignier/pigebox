class network::base {
  package { [netbase, ifupdown, net-tools]: } 
}

class network::dhcp {
  package { dhcp3-client: }
}

class network::dhcp::readonly {
  include network::dhcp
  include readonly::common

  file { "/etc/dhcp3/dhclient.conf":
    source => "$source_base/files/dhcp3/dhclient.conf"
  } 
  file { "/etc/dhcp3/dhclient-script":
    source => "$source_base/files/dhcp3/dhclient-script"
  } 

  file { "/var/etc/resolv.conf":
    ensure => present
  }

  file { "/etc/resolv.conf":
    ensure => "/var/etc/resolv.conf"
  }

  readonly::mount_tmpfs { "/var/lib/dhcp3": }

}

class network::ifplugd {
  package { ifplugd: }
}
