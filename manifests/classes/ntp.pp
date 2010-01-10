class ntp {
  package { [ntp, ntpdate]: }
}

class ntp::readonly {
  include ntp
  readonly::mount_tmpfs { "/var/lib/ntp": }
}
