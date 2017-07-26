require 'spec_helper_acceptance'

test_name 'libkv test'

def set_profile_data_on(host, hiera_yaml, profile_data)

  Dir.mktmpdir do |dir|
    tmp_yaml = File.join(dir, 'hiera.yaml')
    File.open(tmp_yaml, 'w') do |fh|
      fh.puts hiera_yaml
    end
    host.do_scp_to(tmp_yaml, '/etc/puppetlabs/puppet/hiera.yaml', {})
  end
  if (profile_data.class.to_s == "Hash")
    profile_data.each do |filename, data|
      dirname = File.dirname(filename);
      Dir.mktmpdir do |dir|
        unless (Dir.exists?(File.join(dir, dirname)))
          Dir.mkdir(File.join(dir, dirname))
        end
        File.open(File.join(dir, filename), 'w') do |fh|
          fh.puts(data)
          fh.flush

          file = "/etc/puppetlabs/code/environments/production/hieradata/#{filename}"
          on(host, "sudo sh -c 'mkdir -p /etc/puppetlabs/code/environments/production/hieradata/#{dirname}'")
          host.do_scp_to(File.join(dir, filename), file, {})
        end
      end
    end
  else
    Dir.mktmpdir do |dir|
      File.open(File.join(dir, "default" + '.yaml'), 'w') do |fh|
        fh.puts(profile_data)
        fh.flush

        default_file = "/etc/puppetlabs/code/environments/production/hieradata/default.yaml"

        host.do_scp_to(dir + "/default.yaml", default_file, {})
      end
    end
  end
end

describe 'libkv test' do

  servers = hosts_with_role(hosts, 'server')
  servers.each do |server|
    on(server, "puppet config set trusted_server_facts true")
    on(server, "puppet resource package puppetserver ensure=installed")
    on(server, "puppet resource service puppetserver ensure=running enable=true")
    on(server, "echo '*' > /etc/puppetlabs/puppet/autosign.conf")
    server.do_scp_to('./spec/acceptance/site.pp', "/etc/puppetlabs/code/environments/production/manifests/site.pp", {})

    context 'server setup' do

      let(:hiera_yaml) { <<-EOS
---
:backends:
  - yaml
:yaml:
  :datadir: '/etc/puppetlabs/code/environments/production/hieradata'
:hierarchy:
  - 'hosts/%{trusted.certname}'
  - 'default'
                         EOS
      }

      let(:default_hieradata) { <<-EOS
libkv::url: 'consul://127.0.0.1:8500/puppet'
libkv::consul::server: false
libkv::consul::advertise: "%{::ipaddress_eth1}"
                                EOS
      }
      let(:server_hieradata) { <<-EOS
libkv::url: 'consul://127.0.0.1:8500/puppet'
libkv::consul::server: true
libkv::consul::advertise: "%{::ipaddress_eth1}"
                               EOS
      }

      servers = hosts_with_role(hosts, 'server')
      servers.each do |server|
        on(server, "puppet config set trusted_server_facts true")
        on(server, "puppet resource package puppetserver ensure=installed")
        on(server, "puppet resource service puppetserver ensure=running enable=true")
        on(server, "echo '*' > /etc/puppetlabs/puppet/autosign.conf")

        it 'should apply bootstrap' do
          set_profile_data_on(server, hiera_yaml, { "default.yaml" => default_hieradata, "hosts/el7.yaml" => server_hieradata })
          on(server, "sudo /opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/modules/libkv/bootstrap/consul.pp")
        end

        it 'should apply default manifest' do
          on(server, "sudo /opt/puppetlabs/bin/puppet agent -t --server el7", :catch_failures => true, :acceptable_exit_codes => [0,2])
        end

        it 'should be idempotent' do
          on(server, "sudo /opt/puppetlabs/bin/puppet agent -t --server el7", :catch_changes => true)
        end

        it 'should create puppet consul value' do
          on(server, "consul kv put puppet/test consul_test_value")
        end

        it 'should contain file /usr/bin/consul-acl' do
          result = on(server, "ls -la /usr/bin/consul-acl")
          expect(result.stdout).to include("rwxr-xr-x")
        end

        it 'should contain file /usr/bin/consul-create-acl' do
          result = on(server, "ls -la /usr/bin/consul-create-acl")
          expect(result.stdout).to include("rwxr-xr-x")
        end

        it 'should create libkv_token' do
          result = on(server,"ls -la /etc/simp/bootstrap/consul")
          expect(result.stdout).to include("libkv_token")
        end

        it 'should create agent_token' do
          result = on(server, "ls -la /etc/simp/bootstrap/consul")
          expect(result.stdout).to include("agent_token")
        end

        it 'should contain file /usr/bin/consul-acl' do
          result = on(server, "ls -la /usr/bin/consul-acl")
          expect(result.stdout).to include("rwxr-xr-x")
        end

        it 'should contain file /usr/bin/consul-create-acl' do
          result = on(server, "ls -la /usr/bin/consul-create-acl")
          expect(result.stdout).to include("rwxr-xr-x")
        end

        it 'should return puppet/test consul value' do
          result = on(server, "consul kv get puppet/test")
          expect(result.stdout).to include("consul_test_value")
        end
      end
    end

    context 'firewall setup' do

      let(:hiera_yaml) { <<-EOS
---
:backends:
  - yaml
:yaml:
  :datadir: '/etc/puppetlabs/code/environments/production/hieradata'
:hierarchy:
  - 'hosts/%{trusted.certname}'
  - 'default'
                         EOS
      }

      let(:default_hieradata) { <<-EOS
libkv::url: 'consul://127.0.0.1:8500/puppet'
libkv::consul::server: false
libkv::consul::advertise: "%{::ipaddress_eth1}"
                                EOS
      }
      let(:firewall_hieradata) { <<-EOS
libkv::url: 'consul://127.0.0.1:8500/puppet'
libkv::consul::server: true
libkv::consul::firewall: true
libkv::consul::bootstrap: true
libkv::consul:dont_copy_files: true
libkv::consul::advertise: "%{::ipaddress_eth1}"
                                 EOS
      }

      servers = hosts_with_role(hosts, 'server')
      servers.each do |server|
        on(server, "puppet config set trusted_server_facts true")
        on(server, "puppet resource package puppetserver ensure=installed")
        on(server, "puppet resource service puppetserver ensure=running enable=true")
        on(server, "echo '*' > /etc/puppetlabs/puppet/autosign.conf")

        it 'should apply bootstrap' do
          set_profile_data_on(server, hiera_yaml, { "default.yaml" => default_hieradata, "hosts/el7.yaml" => firewall_hieradata })
          on(server, "sudo /opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/modules/libkv/bootstrap/consul.pp")
        end

        it 'should apply default manifest' do
          on(server, "sudo /opt/puppetlabs/bin/puppet agent -t --server el7", :catch_failures => true, :acceptable_exit_codes => [0,2])
        end

        it 'should be idempotent' do
          on(server, "sudo /opt/puppetlabs/bin/puppet agent -t --server el7", :catch_changes => true)
        end

        it 'should be listening on TCP ports 8300, 8301, 8302, 8500, and 8600' do
          result = on(server, "netstat -plnt")
          expect(result.stdout).to include("8300", "8301", "8302", "8500", "8600")
        end

        it 'should be listening on UDP ports 8301, 8302, and 8600' do 
          result = on(server, "netstat -plnu")
          expect(result.stdout).to include("8301", "8302", "8600")
        end
      end
    end

    agents = hosts_with_role(hosts, 'agent')
    agents.each do |agent|
      on(agent, "puppet config set trusted_server_facts true")

      context 'rhel 7 agent test' do

        el7agent = hosts_with_name(hosts, 'el7agent')
        el7agent.each do |el7agent|

          it 'should apply cleanly' do
            on(el7agent, "sudo /opt/puppetlabs/bin/puppet agent -t --server el7", :catch_failures => true, :acceptable_exit_codes => [0,2])
          end

          it 'should be idempotent' do
            on(el7agent, "sudo /opt/puppetlabs/bin/puppet agent -t --server el7", :catch_changes => true)
          end

          it 'should not return consul kv for puppet' do
            result = on(el7agent, "consul kv get puppet/test", :accept_all_exit_codes => true)
            expect(result.exit_code).to_not eq(0)
          end
        end
      end

      context 'rhel 6 agent test' do

        el6agent = hosts_with_name(hosts, 'el6agent')
        el6agent.each do |el6agent|

          it 'should apply cleanly' do
            on(el6agent, "sudo /opt/puppetlabs/bin/puppet agent -t --server el6", :catch_failures => true, :acceptable_exit_codes => [0,2])
          end

          it 'should be idempotent' do
            on(el6agent, "sudo /opt/puppetlabs/bin/puppet agent -t --server el6", :catch_changes => true)
          end

          it 'should not return consul kv for puppet' do
            result = on(el6agent, "consul kv get puppet/test", :accept_all_exit_codes => true)
            expect(result.exit_code).to_not eq(0)
          end
        end
      end
    end
  end
end

# vim: set expandtab ts=2 sw=2:
