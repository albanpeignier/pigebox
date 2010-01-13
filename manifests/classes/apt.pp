# Retrieved from module puppet-apt

class apt {
  exec { "apt-get_update":
    command => "apt-get update",
    refreshonly => true
  }
  Package {
    require => Exec["apt-get_update"]
  }

}

define apt::key($ensure = present, $source) {
  case $ensure {
    present: {
      exec { "/usr/bin/wget -O - '$source' | /usr/bin/apt-key add -":
        unless => "apt-key list | grep -Fqe '${name}'",
        path   => "/bin:/usr/bin",
        before => Exec["apt-get_update"],
        notify => Exec["apt-get_update"],
      }
    }
    
    absent: {
      exec {"/usr/bin/apt-key del ${name}":
        onlyif => "apt-key list | grep -Fqe '${name}'",
      }
    }
  }
}

class apt::local {
  include apt
  file { "/etc/apt/preferences":
    source => "$source_base/files/apt/preferences",
    notify => Exec["apt-get_update"]
  }
}

class apt::tryphon {
  file { "/etc/apt/sources.list.d/tryphon.list":
    source => "$source_base/files/apt/tryphon.list",
    notify => Exec["apt-get_update"],
    require => Apt::Key["C6ADBBD5"]
  }
  apt::key { "C6ADBBD5":
    source => "http://debian.tryphon.org/release.asc"
  }
}

class apt::backport {
  file { "/etc/apt/sources.list.d/lenny-backport.list":
    content => "deb http://www.backports.org/debian lenny-backports main contrib non-free",
    require => Apt::Key["16BA136C"],
    notify => Exec["apt-get_update"]
  }
  apt::key { "16BA136C": 
    source => "http://backports.org/debian/archive.key"
  }
}
