# pcs-misc-scripts

Scripts and configs for pacemaker cluster centos linux

pcs
pcs status
pvdisplay
pvs
pvs -h
lvs
lvdisplay /dev/vgdocker/docker-volumes
mkdir /docker-volumes/
git clone https://github.com/mlucasdasilva/pcs-misc-scripts
cp pcs-misc-scripts/fence_dummy.pl /root/fence_dummy.pl
cp pcs-misc-scripts/fence_virtualbox.pl /root/fence_virtualbox.pl
scp /root/fence_virtualbox.pl docker02:/root/fence_virtualbox.pl
scp /root/fence_dummy.pl docker02:/root/fence_dummy.pl
ssh docker01 ln -s /root/fence_dummy.pl /usr/sbin/fence_dummy
ssh docker02 ln -s /root/fence_dummy.pl /usr/sbin/fence_dummy
ssh docker01 ln -s /root/fence_virtualbox.pl /usr/sbin/fence_virtualbox
ssh docker02 ln -s /root/fence_virtualbox.pl /usr/sbin/fence_virtualbox
ssh docker01 rm  /usr/sbin/fence_vboxmanage
ssh docker02 rm  /usr/sbin/fence_vboxmanage
yum install -y perl-Data-Dumper.x86_64
pcs stonith describe fence_virtualbox
pcs stonith describe fence_dummy
ls -lsha /usr/sbin/fence_virtualbox
pcs stonith create dummy-fencing fence_dummy ipaddr=host
pcs status
pcs resource delete gfs2_res-clone
pcs resource delete clvmd-clone
pcs resource delete dlm-clone
pcs resource delete myapc
pcs status
pcs resource create dlm ocf:pacemaker:controld op monitor interval=30s on-fail=fence clone interleave=true ordered=true
pcs status
pcs status resources
pcs cluster setup --start --name mycluster docker01 docker02 --force
pcs status
systemctl start corosync.service
systemctl start pacemaker.service
pcs status
systemctl enable corosync.service
systemctl enable pacemaker.service
pcs status
ls /docker-volumes/
pcs resource create gfs2_res Filesystem device="/dev/vgdocker/docker-volumes" directory="/docker-volumes" fstype="gfs2" options="noatime,nodiratime"     op monitor interval=10s on-fail=fence clone interleave=true
pcs status
pcs cluster setup --start --name mycluster docker01 docker02  --force
reboot
pcs status
cat /etc/corosync/corosync.conf
