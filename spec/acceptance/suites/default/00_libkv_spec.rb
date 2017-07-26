require 'spec_helper_acceptance'

test_name 'libkv test'

describe 'libkv test' do
  servers = hosts_with_role(hosts, 'server')
  servers.each do |server|
    let(:manifest) {
      <<-EOS
      class { 'libkv::consul': }
      EOS
    }

    let(:manifest_with_server_true) {
      <<-EOS
      class { 'libkv::consul':
        server => true,
      }
      EOS
    }

    context 'default parameters' do
    
      it 'should work with no errors' do
        apply_manifest_on(server, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
	apply_manifest_on(server, manifest, :catch_changes => true)
      end

      it 'should contain file /usr/bin/consul-acl' do
	result = on(server, "ls -la /usr/bin/consul-acl")
	expect(result.stdout).to include("--x--x--x")
      end
    end
  end
end
