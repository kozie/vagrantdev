# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils';

VAGRANTFILE_API_VERSION = "2"
SETTINGS_FILE = "local.yml"

settings = YAML.load_file SETTINGS_FILE

if settings['php'].nil? or settings['php']['version'].nil?
	php_version = 7
else
	php_version = settings['php']['version']
end

available_php_versions = [5.5, 7.0]
unless available_php_versions.include?(php_version)
	abort "Please provide a PHP version from the list #{available_php_versions.join(', ')}"
end

if !Vagrant.has_plugin?("vagrant-hostmanager")
	abort "Please install the 'vagrant-hostmanager' plugin"
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
	
	config.vm.box = 'ubuntu/trusty64'
	config.ssh.forward_agent = true

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  #config.vm.box = "base"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"
	if !settings['fs']['folders'].nil?
		settings['fs']['folders'].each do |name, folder|
			if settings['fs']['type'] == 'nfs'
				config.vm.synced_folder folder['host'], folder['guest'], type: settings['fs']['type'], create: true
			else
				config.vm.synced_folder folder['host'], folder['guest'], type: settings['fs']['type'], create: true, owner: "vagrant", group: "vagrant"
			end
		end
	end

	# Provisioning, run the installation of stuff
	config.vm.provision "shell" do |s|
		s.path = "vagrant/provisioning/install.sh"
		s.args = "#{php_version}"
	end

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.
	config.vm.provider :virtualbox do |box, override|
		override.vm.network "private_network", type: "dhcp"
		override.vm.network "forwarded_port", guest: 80, host: 80, auto_correct: true
		override.vm.network "forwarded_port", guest: 3306, host: 3306, auto_correct: true
		box.memory = 2048
	end

	config.vm.provider :lxc do |lxc, override|
		lxc.customize 'cgroup.memory.limit_in_bytes', '2048M'
	end

	if Vagrant.has_plugin?("vagrant-hostmanager")
		config.hostmanager.enabled = true
		config.hostmanager.manage_host = true
		config.hostmanager.ignore_private_ip = false
		config.hostmanager.include_offline = true

		# Get the dynamic hostname from the running box so we know what to put in
    # /etc/hosts even though we don't specify a static private ip address
    # For more information about why this is necessary see:
    # https://github.com/smdahlen/vagrant-hostmanager/issues/86#issuecomment-183265949
    config.hostmanager.ip_resolver = proc do |vm, resolving_vm|
      if vm.communicate.ready?
        result = ""
        vm.communicate.execute("ifconfig `find /sys/class/net -name 'eth*' -printf '%f\n' | tail -n 1`") do |type, data|
          result << data if type == :stdout
        end
      end
      (ip = /inet addr:(\d+\.\d+\.\d+\.\d+)/.match(result)) && ip[1]
    end
	end

	config.vm.define 'creamdev' do |node|
		# Name the vagrant box after the directory the Vagrantfile is in. If the Vagrantfile
		# is in a directory named 'hypernode-vagrant' assume the name of the parent directory.
		# This is so there is a human readable difference between multiple test environments.
		working_directory = File.basename(Dir.getwd)
		creamdev_vagrant_name = ENV['CREAMDEV_VAGRANT_NAME'] ? ENV['CREAMDEV_VAGRANT_NAME'] : working_directory

		# remove special characters so we have a valid hostname
		creamdev_host = creamdev_vagrant_name.gsub(/[^a-zA-Z0-9\-]/, "") 
		creamdev_host = creamdev_host.empty? ? 'creamdev' : creamdev_host

		directory_alias = creamdev_host + ".dev.cream.nl"

		# The directory and parent directory don't have to be unique names. You
		# could have this Vagrantfile in two subdirs each named 'mytestshop' and
		# the directory aliases would be double. Because there can only be one
		# Vagrantfile per directory, the path is always unique. We can create a
		# unique alias (well at least semi-unique, there might be some
		# collisions) with the hash of that path.
		require 'digest/sha1'
		hostname_hash = Digest::SHA1.hexdigest(Dir.pwd).slice(0..5)
		directory_hash_alias = hostname_hash + ".dev.cream.nl"

		# set the machine hostname
		node.vm.hostname = hostname_hash + "-" + creamdev_host + "-creamdev.local"

		# Here you can define your own aliases for in the hosts file.
		# note: if you have more than one hypernode-vagrant checkout up and
		# running, the static aliases will be defined for all of those boxes.
		# This means that hypernode.local will belong to box you booted as last.
		node.hostmanager.aliases = ["creamdev.local", "creamdev-alias", directory_alias, directory_hash_alias]
	end

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   sudo apt-get update
  #   sudo apt-get install -y apache2
  # SHELL
end
