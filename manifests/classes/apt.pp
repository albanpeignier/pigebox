class apt::local {
  exec { "apt-get_update":
    command => "apt-get update",
    refreshonly => true
  }
  Package {
    require => Exec["apt-get_update"]
  }
}

class apt::tryphon {
  file { "/etc/apt/sources.list.d/tryphon.list":
    source => "$source_base/files/apt/tryphon.list",
    notify => Exec["apt-get_update"]
  }
}
