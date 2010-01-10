class ssh {
  package { ssh: }

  file { "/root/.ssh/authorized_keys":
    source => "$source_base/files/ssh/authorized_keys",
    mode => 700;
    "/root/.ssh": ensure => directory, mode => 700;
  }
}
