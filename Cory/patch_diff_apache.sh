# apache
sudo apt-get -o Dpkg::Options::="--force-confnew" install --reinstall apache2 -y
sudo systemctl restart apache2

#redis
sudo apt-get -o Dpkg::Options::="--force-confnew" install --reinstall redis-server -y
sudo systemctl restart redis-server

