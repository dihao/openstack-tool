# Destroy VMs
for x in $(virsh list --all | grep instance- | awk '{print $2}') ; do
    virsh destroy $x ;
    virsh undefine $x ;
done ;

# Remove installed packages
yum remove -y nrpe "*nagios*" puppet "*ntp*" "*openstack*" \
"*nova*" "*keystone*" "*glance*" "*cinder*" "*swift*" \
mysql mysql-server httpd "*memcache*" scsi-target-utils \
iscsi-initiator-utils perl-DBI perl-DBD-MySQL ;

ps -ef | grep -i repli | grep swift | awk '{print $2}' | xargs kill ;

# Delete local application data
rm -rf /etc/nagios /etc/yum.repos.d/packstack_* /root/.my.cnf \
/var/lib/mysql/ /var/lib/glance /var/lib/nova /etc/nova /etc/swift \
/srv/node/device*/* /var/lib/cinder/ /etc/rsync.d/frag* \
/var/cache/swift /var/log/keystone /var/log/cinder/ /var/log/nova/ \
/var/log/httpd /var/log/glance/ /var/log/nagios/ /var/log/quantum/ ;

umount /srv/node/device* ;
killall -9 dnsmasq tgtd httpd ;
setenforce 1 ;
vgremove -f cinder-volumes ;
losetup -a | sed -e 's/:.*//g' | xargs losetup -d ;
find /etc/pki/tls -name "ssl_ps*" | xargs rm -rf ;
for x in $(df | grep "/lib/" | sed -e 's/.* //g') ; do
    umount $x ;
done

# Delete created bridges
ovs-vsctl --if-exists del-port br-int patch-tun
ovs-vsctl --if-exists del-port br-tun patch-int
ovs-vsctl --if-exists del-port br-tun gre-1
ovs-vsctl --if-exists del-port br-tun gre-2
ovs-vsctl --if-exists del-br br-tun

# Clean the iptables rules generated by openstack
iptables -P INPUT ACCEPT
iptables -F
iptables -X
iptables -Z
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT #ssh
iptables -A INPUT -p tcp -m state --state NEW -m tcp -m multiport --dports 5901:5903,6001:6003 -j ACCEPT #VNC/X-window
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited
iptables -P OUTPUT ACCEPT

service iptables save
if [ -f /etc/sysconfig/iptables ]; then
    sed -i '/nova/d' /etc/sysconfig/iptables 
    sed -i '/neutron/d' /etc/sysconfig/iptables 
fi
service iptables restart


# clean all generated network namespace
for name in `ip netns show`  
do   
    [[ $name == qdhcp-* || $name == qrouter-* ]] &&  ip netns del $name
done

#yum clean all; yum makecache; yum -y update