# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.network "forwarded_port", guest: 8088, host: 8088
  config.vm.network "private_network", ip: "192.168.33.10"
   config.vm.provider "virtualbox" do |vb|
     vb.memory = "1024"
   end
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y curl ruby-dev g++ git 
    sudo gem install em-websocket
    sudo gem install websocket-client-simple
  SHELL
end
