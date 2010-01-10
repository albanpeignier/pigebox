class apache {
  package { apache2-mpm-worker:
    alias => apache
  }

  file { "/etc/apache2/sites-available/default":
    source => "$source_base/files/apache/default",
    require => Package[apache]
  }

  file { "/var/www": ensure => directory, require => Package[apache] }

  file { "/var/log.model/apache2": 
    ensure => directory, 
    owner => root, 
    group => adm
  }

}
