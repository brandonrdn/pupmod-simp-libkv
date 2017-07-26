file { "/etc/simp":
  ensure => directory,
}
file { "/etc/simp/bootstrap/":
  ensure => directory,
}
file { "/etc/simp/bootstrap/consul":
  ensure => directory,
}
exec { "/usr/bin/uuidgen >/etc/simp/bootstrap/consul/master_token":
  creates => '/etc/simp/bootstrap/consul/master_token',
  require => File["/etc/simp/bootstrap/consul"],
} ->
exec { "/opt/puppetlabs/bin/puppet cert generate server.dc1.consul":
  creates => '/etc/puppetlabs/puppet/ssl/private_keys/server.dc1.consul.pem',
} ->
file { "/etc/simp/bootstrap/consul/server.dc1.consul.private.pem":
  source => '/etc/puppetlabs/puppet/ssl/private_keys/server.dc1.consul.pem',
} ->
file { "/etc/simp/bootstrap/consul/server.dc1.consul.cert.pem":
  source => '/etc/puppetlabs/puppet/ssl/certs/server.dc1.consul.pem',
} ->
file { "/etc/simp/bootstrap/consul/ca.pem":
  source => '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem',
  } -> 
  class { "libkv::consul":
    dont_copy_files => true,
    bootstrap       => true,
    server          => true,
  } ->
  exec { "/usr/local/bin/consul keygen >/etc/simp/bootstrap/consul/key":
    path => $::path,
    creates => '/etc/simp/bootstrap/consul/key',
  } ->
  file { "/opt/puppetlabs/facter/facts.d/consul_bootstrap.sh":
    mode    => "a+x",
    content => "#!/bin/sh\necho 'consul_bootstrap=true'",
  }
