# apache
sudo apt-get -o Dpkg::Options::="--force-confnew" install --reinstall apache2 -y
sudo systemctl restart apache2

#redis
sudo pkill redis-server
sudo apt-get purge redis-server -y
sudo apt-get install redis-server -y
sudo systemctl restart redis-server

