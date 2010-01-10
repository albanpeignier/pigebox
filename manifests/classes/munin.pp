class munin {
  package { munin: }
  
  file { "/etc/munin/munin.conf":
    source => "$source_base/files/munin/munin.conf",
    require => Package[munin]
  }

}

class munin::readonly {
  include munin

  readonly::mount_tmpfs { ["/var/lib/munin","/var/www/munin"]: }

  file { "/var/log.model/munin": 
    ensure => directory, 
    owner => munin, 
    group => adm
  }
}

class munin-node {
  package { "munin-node": }

  file { "/etc/munin/munin-node.conf":
    source => "$source_base/files/munin/munin-node.conf",
    require => Package["munin-node"]
  }

  file { "/etc/munin/plugins/df":
    ensure => "/usr/share/munin/plugins/df"
  }
}
