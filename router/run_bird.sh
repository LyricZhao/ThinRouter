# test on Ubuntu 18.04
echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
bird -c /etc/bird/bird.conf 
tail -F ~/bird.log
