class smtp {
  # disable exim4 installed by default
  package { "exim4-daemon-light": ensure => purged }
}
