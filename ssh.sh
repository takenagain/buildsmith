sudo apt install -y openssh-server

ssh-keygen -t rsa -b 4096

sudo systemctl try-reload-or-restart ssh
