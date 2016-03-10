# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "hashicorp/precise64"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.network "private_network", ip: "192.168.33.10"

   config.vm.provider "virtualbox" do |vb|
     # Display the VirtualBox GUI when booting the machine
     vb.gui = true
  
     # Customize the amount of memory on the VM:
     vb.memory = "1024"
   end
  

  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y curl ruby-dev g++ git 
    sudo gem install em-websocket
    sudo gem install websocket-client-simple
    curl -o /tmp/go1.6.linux-amd64.tar.gz https://storage.googleapis.com/golang/go1.6.linux-amd64.tar.gz
    \rm -fr /usr/local/go
    tar -C /usr/local -zxf /tmp/go1.6.linux-amd64.tar.gz
  SHELL
end


