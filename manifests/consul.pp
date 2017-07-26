# == Class libkv::consul
# vim: set expandtab ts=2 sw=2:
#
# This class uses solarkennedy/consul to initialize .
#
class libkv::consul(
  $server = false,
  $version = '0.8.5',
  $use_puppet_pki = true,
  $bootstrap = false,
  $dont_copy_files = false,
  $serverhost = undef,
  $http_listen = '127.0.0.1',
  $https_listen = '0.0.0.0',
  $advertise = undef,
  $datacenter = undef,
  $puppet_cert_path,
  $ca_file_name = undef,
  $private_file_name = undef,
  $cert_file_name = undef,
  $config_hash = undef,
  $agent_token = undef,
) {
  if ($firewall) {
    $ports = [
      '8300',
      '8301',
      '8302',
      '8501',
    ]
    $ports.each |$port| {
      iptables::listen::tcp_stateful { "libkv::consul - tcp - ${port}":
        dports => $port,
      }
      iptables::listen::udp { "libkv::consul - udp - ${port}":
        dports => $port,
      }
    }
  }
  package { "unzip": }
  file { "/usr/bin/consul-acl":
    ensure => 'file',
    mode   => "a+x",
    source => "puppet:///modules/libkv/consul/consul-acl"
  }
  file { "/usr/bin/consul-create-acl":
    ensure => 'file',
    mode   => "a+x",
    source => "puppet:///modules/libkv/consul/consul-create-acl"
  }
  if ($bootstrap == true) {
    $_bootstrap_hash = { "bootstrap_expect" => 1 }
  } else {
    $type = type($facts['consul_bootstrap'])
    notify { "consul_bootstrap = ${type}": }
    if ($facts["consul_bootstrap"] == "true") {
      $_bootstrap_hash = { "bootstrap_expect" => 1 }
      ## Create real token
      exec { "/usr/bin/consul-create-acl -t libkv /etc/simp/bootstrap/consul/master_token /etc/simp/bootstrap/consul/libkv_token":
        creates => "/etc/simp/bootstrap/consul/libkv_token",
        require => [
          Service['consul'],
          File["/usr/bin/consul-acl"],
        ],
      }
      exec { "/usr/bin/consul-create-acl -t agent_token /etc/simp/bootstrap/consul/master_token /etc/simp/bootstrap/consul/agent_token":
        creates => "/etc/simp/bootstrap/consul/agent_token",
        require => [
          Service['consul'],
          File["/usr/bin/consul-acl"],
        ],
      }
    } else {
      $_bootstrap_hash = {}
    }
  }
  if ($datacenter == undef) {
    $_datacenter = {}
  } else {
    $_datacenter = { "datacenter" => $datacenter }
  }
  if ($serverhost == undef) {
    if ($::servername == undef) {
      $_serverhost = $::fqdn
    } else {
      $_serverhost = $::servername
    }
  } else {
    $_serverhost = $serverhost
  }
  if ($advertise == undef) {
    $_advertise = $::ipaddress
  } else {
    $_advertise = $advertise
  }
  $keypath = '/etc/simp/bootstrap/consul/key'
  $keydata = file($keypath, "/dev/null")
  if ($keydata != undef) {
    $_key_hash = { 'encrypt' => $keydata.chomp }
  } else {
    $_key_hash = {}
  }
  if ($agent_token == undef) {
  $master_token_path = '/etc/simp/bootstrap/consul/master_token'
  $master_token = file($master_token_path, "/dev/null")
  if ($server == true) {
    if ($master_token != undef) {
      $_token_hash = { 
      "acl_master_token" => $master_token.chomp,
      "acl_token"        => $master_token.chomp,
      }
    } else {
      $_token_hash = {}
    }
  } else {
    $_agent_token = libkv::get({"softfail" => true, "key" => "/simp/libkv/consul/acls/${::clientcert}-${::hostname}"})
    if ($_agent_token != undef) {
      $_token_hash = { 
      "acl_token"        => $_agent_token.chomp,
      }
    } else {
      $try_agent_token = generate("/usr/bin/consul-acl", "-t", "agent",  "gen", "${::clientcert}", "${::hostname}").chomp
      if ($try_agent_token != "") {
        $result = libkv::put({"softfail" => true, "key" => "/simp/libkv/consul/acls/${::clientcert}-${::hostname}", "value" => $try_agent_token.chomp})
        $_token_hash = {
          "acl_token" => $try_agent_token.chomp,
        }
      } else {
        $_token_hash = {}
      }
    }
  }
  } else {
    $_token_hash = {
      "acl_token" => $agent_token,
    }
  }
  if ($use_puppet_pki == true) {
    if ($bootstrap == false) {
      if (!defined(File['/etc/simp'])) {
        file { "/etc/simp":
          ensure => directory,
        }
      }
    }
    file { "/etc/simp/consul":
      ensure => directory,
    }
    if ($server == true) {
      $_cert_file_name = '/etc/simp/bootstrap/consul/server.dc1.consul.cert.pem'
      $_private_file_name = '/etc/simp/bootstrap/consul/server.dc1.consul.private.pem'
      $_ca_file_name = '/etc/simp/bootstrap/consul/ca.pem'
      if ($dont_copy_files == false) {
        file { "/etc/simp/bootstrap/":
          ensure => directory,
        }
        file { "/etc/simp/bootstrap/consul":
          ensure => directory,
        }
        file { $_cert_file_name:
          content => file($_cert_file_name)
        }
        file { $_private_file_name:
          content => file($_private_file_name)
        }
        file { $_ca_file_name:
          content => file($_ca_file_name)
        }
        file { '/etc/simp/consul/cert.pem':
          content => file($_cert_file_name)
        }
        file { '/etc/simp/consul/key.pem':
          content => file($_private_file_name)
        }
        file { '/etc/simp/consul/ca.pem':
          content => file($_ca_file_name)
        }
      }
    } else {
      $_cert_file_name_source = "${puppet_cert_path}/certs/${::clientcert}.pem"
      $_ca_file_name_source = "${puppet_cert_path}/certs/ca.pem"
      $_private_file_name_source = "${puppet_cert_path}/private_keys/${::clientcert}.pem"
      file { '/etc/simp/consul/cert.pem':
        source => $_cert_file_name_source
      }
      file { '/etc/simp/consul/ca.pem':
        source => $_ca_file_name_source
      }
      file { '/etc/simp/consul/key.pem':
        source => $_private_file_name_source
      }
    }
    if ($bootstrap == false) {
      $_cert_hash = {
        "cert_file"              => '/etc/simp/consul/cert.pem',
        "ca_file"                => '/etc/simp/consul/ca.pem',
        "key_file"               => '/etc/simp/consul/key.pem',
        "verify_outgoing"        => true,
        "verify_incoming"        => true,
        "verify_server_hostname" => true,
      }
    } else {
      $_cert_hash = {}
    }
  }
  # Attempt to store bootstrap info into consul directly via libkv.
  # Use softfail to get around issues if the service isn't up
  $hash = lookup('consul::config_hash', { "default_value" => {} })
  $class_hash =     {
    'server'         => $server,
    'node_name'      => $::hostname,
    'retry_join'     => [ $_serverhost ],
    'advertise_addr' => $_advertise,
    'addresses'      => {
      'http'         => $http_listen,
      'https'        => $https_listen,
    },
  }
  $merged_hash = $hash + $class_hash + $_datacenter + $config_hash + $_key_hash + $_token_hash + $_bootstrap_hash + $_cert_hash
  class { '::consul':
    config_hash          => $merged_hash,
    version => $version,
  }
  file { "/usr/bin/consul":
    target => "/usr/local/bin/consul",
  }
}
