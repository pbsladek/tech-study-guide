require "cgi"
require "json"
require "minitest/autorun"
require "yaml"

class SiteTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  COMMAND_BLOCKS = {
    "docs/troubleshooting/index.html" => [
      "date -Is",
      "hostnamectl",
      "systemctl --failed",
      "journalctl -p warning..alert -b",
      "kubectl get events --all-namespaces --sort-by=.lastTimestamp",
      "curl -v https://example.com/",
      "dig example.com"
    ],
    "docs/linux/index.html" => [
      "ls -l /proc/<pid>/fd",
      "lsof -p <pid>",
      "ulimit -n",
      "cat /proc/sys/fs/file-nr"
    ],
    "docs/linux/lvm/index.html" => [
      "lsblk",
      "pvcreate /dev/sdb",
      "vgcreate vg_data /dev/sdb",
      "lvcreate -n lv_apps -L 100G vg_data",
      "mkfs.xfs /dev/vg_data/lv_apps",
      "mkdir -p /srv/apps",
      "mount /dev/vg_data/lv_apps /srv/apps"
    ],
    "docs/linux/systemd/index.html" => [
      "systemctl status nginx.service",
      "systemctl start nginx.service",
      "systemctl restart nginx.service",
      "systemctl reload nginx.service",
      "systemctl enable nginx.service",
      "systemctl disable nginx.service",
      "systemctl daemon-reload"
    ],
    "docs/linux/systemd-networking/index.html" => [
      "networkctl status",
      "networkctl list",
      "resolvectl status",
      "systemctl status systemd-networkd systemd-resolved",
      "journalctl -u systemd-networkd -b",
      "systemd-analyze critical-chain network-online.target"
    ],
    "docs/linux/systemd-socket-network-services/index.html" => [
      "systemctl list-sockets",
      "systemctl status ssh.socket",
      "systemctl cat ssh.socket",
      "systemctl show <service> -p IPAccounting -p IPAddressDeny -p SocketBindDeny",
      "journalctl -u <service> -b",
      "ss -tulpen"
    ],
    "docs/linux/resolv-conf/index.html" => [
      "readlink -f /etc/resolv.conf",
      "cat /etc/resolv.conf",
      "resolvectl status",
      "resolvectl query example.com",
      "journalctl -u systemd-resolved -b"
    ],
    "docs/linux/boot-userspace/index.html" => [
      "cat /proc/cmdline",
      "journalctl -b",
      "systemd-analyze time",
      "systemd-analyze critical-chain",
      "lsinitrd 2>/dev/null || lsinitramfs /boot/initrd.img-$(uname -r)",
      "findmnt /"
    ],
    "docs/linux/network-boot-automated-provisioning/index.html" => [
      "tcpdump -ni <interface> 'port 67 or port 68 or port 69 or port 80 or port 4011'",
      "journalctl -u isc-dhcp-server -u dnsmasq -u tftpd-hpa --no-pager",
      "curl -fsS http://<boot-server>/boot.ipxe",
      "curl -fsS http://<boot-server>/autoinstall/user-data",
      "ls -l /srv/tftp /var/lib/tftpboot /var/www/html"
    ],
    "docs/linux/kernel-modules-devices/index.html" => [
      "lsmod",
      "modinfo <module>",
      "modprobe --show-depends <module>",
      "cat /proc/modules",
      "find /sys -name modalias -print | head",
      "udevadm info --query=all --name=/dev/sda | head",
      "dmesg -T | grep -i -E 'module|firmware|udev|driver|taint'"
    ],
    "docs/linux/filesystems-io/index.html" => [
      "findmnt",
      "df -h",
      "df -i",
      "lsblk -f",
      "iostat -xz 1",
      "journalctl -k -g 'I/O error|EXT4|XFS|blk|nvme|scsi'"
    ],
    "docs/linux/block-devices-partitions/index.html" => [
      "lsblk -o NAME,MAJ:MIN,SIZE,TYPE,FSTYPE,MOUNTPOINTS",
      "blkid",
      "udevadm info --query=all --name=/dev/sda | head",
      "parted -l",
      "cat /proc/partitions"
    ],
    "docs/linux/mounts-fstab/index.html" => [
      "findmnt",
      "findmnt --verify",
      "cat /etc/fstab",
      "systemctl list-units --type=mount",
      "mount -a -v"
    ],
    "docs/linux/mount-namespaces-propagation/index.html" => [
      "findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS,PROPAGATION",
      "readlink /proc/<pid>/ns/mnt",
      "cat /proc/<pid>/mountinfo",
      "lsns -t mnt",
      "nsenter --target <pid> --mount -- findmnt"
    ],
    "docs/linux/ext4-xfs-repair/index.html" => [
      "df -hT",
      "df -i",
      "lsblk -f",
      "sudo xfs_info /mountpoint",
      "sudo tune2fs -l /dev/sdX1 | head",
      "journalctl -k -g 'EXT4|XFS|I/O error|readonly'"
    ],
    "docs/linux/raid-multipath-device-mapper/index.html" => [
      "cat /proc/mdstat",
      "mdadm --detail --scan",
      "dmsetup ls --tree",
      "multipath -ll",
      "cryptsetup status <name>",
      "lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS"
    ],
    "docs/linux/storage-drives-raid-database-performance/index.html" => [
      "lsblk -o NAME,TYPE,MODEL,SERIAL,ROTA,SIZE,FSTYPE,MOUNTPOINTS",
      "cat /proc/mdstat",
      "mdadm --detail /dev/md0",
      "iostat -xz 1",
      "smartctl -a /dev/sda",
      "nvme smart-log /dev/nvme0"
    ],
    "docs/linux/storage-health-performance/index.html" => [
      "iostat -xz 1",
      "lsblk -D",
      "smartctl -a /dev/sda",
      "nvme smart-log /dev/nvme0",
      "dmesg -T | grep -Ei 'I/O error|medium error|nvme|scsi|reset'",
      "journalctl -k -p warning..alert"
    ],
    "docs/linux/containerization-oci-vms/index.html" => [
      "docker info",
      "docker image inspect <image>",
      "docker container inspect <container>",
      "cat /proc/<pid>/status",
      "cat /proc/<pid>/cgroup",
      "readlink /proc/<pid>/ns/*",
      "cat /proc/<pid>/mountinfo",
      "lsns -p <pid>",
      "docker network inspect bridge",
      "ip link show type bridge",
      "bridge link",
      "nft list ruleset"
    ],
    "docs/linux/network-stack/index.html" => [
      "ip addr",
      "ip route",
      "ip rule",
      "ip neigh",
      "ss -tulpen",
      "nft list ruleset",
      "cat /proc/net/softnet_stat",
      "ip link show type bridge",
      "bridge link"
    ],
    "docs/linux/kernel-network-performance/index.html" => [
      "sar -n DEV,TCP,ETCP 1",
      "ss -s",
      "ip -s link",
      "ethtool -S <interface>",
      "cat /proc/net/softnet_stat",
      "mpstat -P ALL 1"
    ],
    "docs/linux/ebpf-tracing/index.html" => [
      "uname -r",
      "bpftool feature probe",
      "bpftool prog show",
      "bpftool map show",
      "bpftrace -l 'tracepoint:syscalls:sys_enter_*' | head"
    ],
    "docs/linux/memory-pressure-oom/index.html" => [
      "free -h",
      "cat /proc/meminfo",
      "cat /proc/pressure/memory",
      "vmstat 1",
      "ps -eo pid,ppid,comm,rss,vsz,%mem --sort=-rss | head",
      "journalctl -k -g 'Out of memory|Killed process|oom-kill'"
    ],
    "docs/linux/syscall-debugging/index.html" => [
      "strace -f -p <pid>",
      "strace -ff -o /tmp/trace.log <command>",
      "strace -f -e trace=file,network -p <pid>",
      "strace -ttT -f -p <pid>",
      "strace -yy -s 256 -f -e trace=network,desc -p <pid>",
      "strace -c -f <command>",
      "strace -f -e status=failed <command>",
      "cat /proc/<pid>/syscall"
    ],
    "docs/linux/security-controls/index.html" => [
      "id",
      "sudo -l",
      "getcap -r /usr/bin /usr/sbin 2>/dev/null",
      "aa-status 2>/dev/null || true",
      "sestatus 2>/dev/null || true",
      "journalctl -k -g 'apparmor|SELinux|seccomp|audit'"
    ],
    "docs/linux/package-boot-recovery/index.html" => [
      "cat /etc/os-release",
      "uname -a",
      "systemctl --failed",
      "journalctl -xb",
      "dpkg --audit",
      "apt-mark showhold"
    ],
    "docs/linux/performance-triage-runbooks/index.html" => [
      "uptime",
      "vmstat 1",
      "mpstat -P ALL 1",
      "iostat -xz 1",
      "pidstat -durh 1",
      "cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io"
    ],
    "docs/linux/tcp-kernel-tuning/index.html" => [
      "sysctl net.core.somaxconn",
      "sysctl net.ipv4.tcp_max_syn_backlog",
      "sysctl net.ipv4.ip_local_port_range",
      "sysctl net.ipv4.tcp_fin_timeout",
      "ss -ltn",
      "cat /proc/net/sockstat"
    ],
    "docs/linux/sockets-ipc/index.html" => [
      "ss -tulpen",
      "ss -xap",
      "lsof -p <pid>",
      "ls -l /proc/<pid>/fd",
      "cat /proc/net/sockstat",
      "sysctl net.core.somaxconn"
    ],
    "docs/linux/processes-threads/index.html" => [
      "ps -eLf",
      "pstree -ap",
      "top -H -p <pid>",
      "cat /proc/<pid>/status",
      "ls /proc/<pid>/task",
      "cat /proc/<pid>/limits"
    ],
    "docs/linux/debian-ubuntu/index.html" => [
      "cat /etc/os-release",
      "uname -a",
      "apt-cache policy",
      "systemctl --failed",
      "journalctl -p warning..alert -b",
      "ls -l /etc/netplan"
    ],
    "docs/linux/users-permissions-sudo/index.html" => [
      "id",
      "getent passwd",
      "getent group sudo",
      "sudo -l",
      "ls -l /etc/passwd /etc/shadow /etc/sudoers",
      "sudo visudo -c"
    ],
    "docs/linux/ssh-access/index.html" => [
      "sudo systemctl status ssh",
      "sudo sshd -T",
      "grep -R '^[^#]' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null",
      "journalctl -u ssh -b",
      "ssh -vvv user@example.com"
    ],
    "docs/linux/logs-observability/index.html" => [
      "journalctl -b",
      "journalctl -p warning..alert -b",
      "journalctl -u ssh -b",
      "dmesg -T | tail -100",
      "ls -lh /var/log",
      "systemctl status systemd-journald"
    ],
    "docs/linux/scheduled-automation/index.html" => [
      "systemctl list-timers --all",
      "crontab -l",
      "sudo ls -l /etc/cron.d /etc/cron.daily /var/spool/cron/crontabs",
      "systemctl status cron",
      "journalctl -u cron -b"
    ],
    "docs/linux/backup-transfer-rsync-scp-snapshots/index.html" => [
      "rsync --version",
      "rsync -aHAXn --delete /srv/app/ backup:/backups/app/",
      "scp -v file.txt user@host:/tmp/",
      "ssh user@host 'hostname; df -h; umask'",
      "findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /srv/app"
    ],
    "docs/linux/time-hostname/index.html" => [
      "timedatectl",
      "systemctl status systemd-timesyncd",
      "journalctl -u systemd-timesyncd -b",
      "date -Is",
      "hostnamectl",
      "cat /etc/hostname"
    ],
    "docs/linux/gpu-drivers/index.html" => [
      "lspci -nnk | grep -A4 -E 'VGA|3D|Display'",
      "lsmod | grep -E 'amdgpu|radeon|nvidia|nouveau'",
      "ls -l /dev/dri /dev/nvidia* 2>/dev/null",
      "dmesg -T | grep -Ei 'drm|amdgpu|nvidia|nouveau|xid|firmware'",
      "cat /proc/driver/nvidia/version 2>/dev/null",
      "nvidia-smi 2>/dev/null"
    ],
    "docs/kubernetes/index.html" => [
      "kubectl apply -f deployment.yaml"
    ],
    "docs/kubernetes/core-concepts/index.html" => [
      "kubectl get pods --all-namespaces",
      "kubectl describe pod <pod-name>",
      "kubectl explain deployment.spec",
      "kubectl get deployment <name> -o yaml",
      "kubectl get pod <pod-name> -o jsonpath='{.status.conditions}'"
    ],
    "docs/kubernetes/troubleshooting/index.html" => [
      "kubectl get nodes",
      "kubectl get pods --all-namespaces -o wide",
      "kubectl get events --sort-by=.lastTimestamp",
      "kubectl get deployment,statefulset,daemonset,job,cronjob --all-namespaces",
      "kubectl get svc,endpointslice,ingress,networkpolicy --all-namespaces",
      "kubectl get pv,pvc,storageclass --all-namespaces"
    ],
    "docs/identity/auth-protocols/index.html" => [
      "curl -sS https://<idp-domain>/.well-known/openid-configuration",
      "curl -sS https://<idp-domain>/.well-known/jwks.json",
      "openssl x509 -in <saml-signing-cert.pem> -noout -subject -issuer -dates -fingerprint -sha256",
      "python3 -m json.tool <token-payload.json>"
    ],
    "docs/kubernetes/dns-coredns/index.html" => [
      "kubectl -n kube-system get deploy,svc,endpointslice -l k8s-app=kube-dns",
      "kubectl -n kube-system logs deployment/coredns",
      "kubectl exec -it <pod> -- cat /etc/resolv.conf",
      "kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local",
      "kubectl -n kube-system get configmap coredns -o yaml"
    ],
    "docs/kubernetes/nats-dns-kubernetes/index.html" => [
      "kubectl -n <namespace> get statefulset,svc,endpointslice,pod -l app.kubernetes.io/name=nats",
      "kubectl -n <namespace> get svc <nats-service> <nats-headless-service> -o wide",
      "kubectl -n <namespace> get endpointslice -l kubernetes.io/service-name=<nats-headless-service>",
      "kubectl -n <namespace> exec -it <debug-pod> -- nslookup <nats-service>.<namespace>.svc.cluster.local",
      "kubectl -n <namespace> exec -it <debug-pod> -- nslookup <nats-0>.<nats-headless-service>.<namespace>.svc.cluster.local",
      "kubectl -n <namespace> exec -it <debug-pod> -- nslookup -type=SRV _nats._tcp.<nats-headless-service>.<namespace>.svc.cluster.local",
      "kubectl -n <namespace> logs statefulset/<nats-statefulset> --all-containers"
    ],
    "docs/kubernetes/external-dns/index.html" => [
      "kubectl -n external-dns get deploy,sa,secret",
      "kubectl -n external-dns logs deployment/external-dns",
      "kubectl get ingress,svc,gateway,httproute --all-namespaces",
      "kubectl describe ingress <name> -n <namespace>",
      "dig <hostname>"
    ],
    "docs/kubernetes/services-endpointslices/index.html" => [
      "kubectl get svc <service> -o wide",
      "kubectl describe svc <service>",
      "kubectl get endpointslice -l kubernetes.io/service-name=<service>",
      "kubectl get pods -l <selector> -o wide",
      "kubectl describe pod <pod>",
      "kubectl get events --sort-by=.lastTimestamp"
    ],
    "docs/kubernetes/pod-networking-cni/index.html" => [
      "kubectl get nodes -o wide",
      "kubectl get pods -A -o wide",
      "kubectl describe node <node>",
      "kubectl -n kube-system get pods -o wide",
      "kubectl exec -it <pod> -- ip addr",
      "kubectl exec -it <pod> -- ip route"
    ],
    "docs/kubernetes/network-policy/index.html" => [
      "kubectl get networkpolicy -A",
      "kubectl describe networkpolicy <policy>",
      "kubectl get pods --show-labels",
      "kubectl get namespace --show-labels",
      "kubectl exec -it <pod> -- nc -vz <service> <port>",
      "kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local"
    ],
    "docs/kubernetes/ingress-gateway-load-balancers/index.html" => [
      "kubectl get ingress,gateway,httproute --all-namespaces",
      "kubectl describe ingress <name>",
      "kubectl describe gateway <name>",
      "kubectl get svc -A --field-selector spec.type=LoadBalancer",
      "kubectl get endpointslice -l kubernetes.io/service-name=<service>",
      "curl -vk https://<host>/"
    ],
    "docs/dns/index.html" => [
      "getent hosts www.example.com",
      "getent ahosts www.example.com",
      "cat /etc/nsswitch.conf",
      "readlink -f /etc/resolv.conf",
      "cat /etc/resolv.conf",
      "resolvectl status",
      "resolvectl query www.example.com",
      "tcpdump -nn -i any 'port 53'"
    ],
    "docs/dns/resolution-caching/index.html" => [
      "getent hosts example.com",
      "dig example.com A",
      "dig example.com AAAA",
      "dig +trace example.com",
      "dig @1.1.1.1 example.com",
      "nslookup example.com",
      "nslookup -type=SRV _ldap._tcp.dc._msdcs.example.com",
      "nslookup -debug example.com",
      "nslookup -vc example.com"
    ],
    "docs/dns/authoritative-zones/index.html" => [
      "dig NS example.com",
      "dig SOA example.com",
      "dig @ns1.example.com example.com SOA",
      "dig @ns1.example.com www.example.com A +norecurse",
      "dig +trace www.example.com"
    ],
    "docs/dns/dnssec-privacy/index.html" => [
      "dig +dnssec example.com",
      "dig DS example.com",
      "dig DNSKEY example.com",
      "delv example.com",
      "resolvectl query example.com"
    ],
    "docs/dns/records-transport-operations/index.html" => [
      "dig example.com A",
      "dig example.com AAAA",
      "dig example.com MX",
      "dig example.com TXT",
      "dig +bufsize=1232 example.com DNSKEY",
      "dig +tcp example.com DNSKEY",
      "dig -x 203.0.113.10"
    ],
    "docs/dns/domain-controllers/index.html" => [
      "dig _ldap._tcp.dc._msdcs.example.com SRV",
      "dig _kerberos._tcp.example.com SRV",
      "dig example.com SOA",
      "nslookup -type=SRV _ldap._tcp.dc._msdcs.example.com",
      "nltest /dsgetdc:example.com",
      "dcdiag /test:dns"
    ],
    "docs/networking/index.html" => [
      "ip addr",
      "ip link",
      "ip route",
      "ip neigh",
      "ss -tuna",
      "traceroute example.com",
      "ping -M do -s 1472 example.com",
      "tcpdump -nn -i any host example.com"
    ],
    "docs/networking/packet-path/index.html" => [
      "ip addr",
      "ip route get 203.0.113.10",
      "ip rule",
      "ip neigh",
      "ss -tuna",
      "tcpdump -nn -i any host 203.0.113.10"
    ],
    "docs/networking/packet-capture-analysis/index.html" => [
      "ip addr",
      "ip route get 203.0.113.10",
      "tcpdump -D",
      "sudo tcpdump -nn -i any host 203.0.113.10",
      "sudo tcpdump -nn -i eth0 'tcp port 443 and host 203.0.113.10'"
    ],
    "docs/networking/bgp-dynamic-routing/index.html" => [
      "show bgp summary",
      "show bgp ipv4 unicast",
      "show route protocol bgp",
      "show bgp neighbors",
      "show bgp <prefix>"
    ],
    "docs/networking/cloud-networking/index.html" => [
      "ip addr",
      "ip route",
      "curl -sS ifconfig.me",
      "traceroute 203.0.113.10",
      "dig api.example.com"
    ],
    "docs/networking/network-namespaces-virtual-networking/index.html" => [
      "ip netns list",
      "lsns -t net",
      "readlink /proc/<pid>/ns/net",
      "nsenter --target <pid> --net -- ip addr",
      "nsenter --target <pid> --net -- ip route"
    ],
    "docs/networking/ipv6-operations/index.html" => [
      "ip -6 addr",
      "ip -6 route",
      "ip -6 neigh",
      "resolvectl query example.com AAAA",
      "ping -6 2001:4860:4860::8888",
      "tracepath6 example.com"
    ],
    "docs/networking/http-proxy-debugging/index.html" => [
      "curl -v https://api.example.com/healthz",
      "curl -vk --resolve api.example.com:443:203.0.113.10 https://api.example.com/healthz",
      "curl -v --http1.1 https://api.example.com/",
      "curl -v --http2 https://api.example.com/",
      "env | grep -i proxy"
    ],
    "docs/networking/routing-nat-firewalls/index.html" => [
      "ip route",
      "ip route get 198.51.100.10",
      "ip rule",
      "nft list ruleset",
      "conntrack -S",
      "conntrack -L | head"
    ],
    "docs/networking/nat-gateways/index.html" => [
      "ip route get 198.51.100.10",
      "ip rule",
      "nft list ruleset",
      "conntrack -S",
      "conntrack -L -p tcp --orig-src 10.0.0.10 2>/dev/null | head",
      "ss -tan state established",
      "tcpdump -nn -i any 'host 198.51.100.10 or host 10.0.0.10'"
    ],
    "docs/networking/firewalls-iptables-netfilter/index.html" => [
      "nft list ruleset",
      "iptables-save",
      "ip6tables-save",
      "conntrack -S",
      "conntrack -L | head",
      "journalctl -k -g 'DROP|REJECT|nft|iptables|conntrack'"
    ],
    "docs/networking/vpn-ipsec-tunnels/index.html" => [
      "ip route",
      "ip rule",
      "ip xfrm state",
      "ip xfrm policy",
      "ipsec statusall",
      "tcpdump -nn -i any udp port 500 or udp port 4500 or esp",
      "ping -M do -s 1372 <remote-ip>"
    ],
    "docs/networking/dhcp-routers-switches/index.html" => [
      "ip addr",
      "ip route",
      "resolvectl status 2>/dev/null || cat /etc/resolv.conf",
      "journalctl -b -u systemd-networkd -u NetworkManager --no-pager",
      "tcpdump -ni <interface> 'udp port 67 or udp port 68'",
      "dhclient -v -r <interface> 2>/dev/null || true",
      "dhclient -v <interface> 2>/dev/null || true"
    ],
    "docs/networking/switching-vlans-hosts/index.html" => [
      "ip link",
      "bridge link",
      "bridge vlan show",
      "ip -d link show",
      "cat /etc/hosts",
      "getent hosts example.internal"
    ],
    "docs/networking/ip-addressing-subnetting/index.html" => [
      "ip addr show",
      "ip route show",
      "ip route get 198.51.100.10",
      "ip -6 route show",
      "ip -6 neigh show",
      "getent ahosts example.com"
    ],
    "docs/networking/icmp-mtu-path-testing/index.html" => [
      "ping -c 4 198.51.100.10",
      "ping -M do -s 1472 198.51.100.10",
      "tracepath 198.51.100.10",
      "traceroute 198.51.100.10",
      "ip link show",
      "tcpdump -nn -i any icmp or icmp6"
    ],
    "docs/networking/tcp-tls-http/index.html" => [
      "nc -vz example.com 443",
      "openssl s_client -connect example.com:443 -servername example.com",
      "curl -v https://example.com/",
      "ss -ti dst example.com",
      "tcpdump -nn -i any host example.com and port 443"
    ],
    "docs/networking/certificates-https/index.html" => [
      "openssl s_client -connect example.com:443 -servername example.com -showcerts",
      "curl -Iv https://example.com/",
      "openssl x509 -in server.crt -noout -text",
      "update-ca-certificates --fresh",
      "ls -l /etc/ssl/certs/ca-certificates.crt"
    ],
    "docs/networking/tcp-sockets/index.html" => [
      "ss -ltnp",
      "ss -tan state established",
      "ss -ti dst 203.0.113.10",
      "sysctl net.ipv4.ip_local_port_range",
      "sysctl net.core.somaxconn",
      "cat /proc/net/sockstat"
    ],
    "docs/networking/udp-quic-connectionless/index.html" => [
      "ss -uan",
      "sudo tcpdump -nn -i any udp",
      "conntrack -L -p udp 2>/dev/null | head",
      "dig +notcp example.com A",
      "dig +tcp example.com A",
      "openssl s_client -connect example.com:443 -servername example.com"
    ],
    "docs/networking/load-balancers-proxies/index.html" => [
      "curl -v https://example.com/",
      "curl -vk --resolve example.com:443:198.51.100.10 https://example.com/",
      "openssl s_client -connect example.com:443 -servername example.com",
      "dig example.com A",
      "ss -tan state established",
      "tcpdump -nn -i any host 198.51.100.10"
    ],
    "docs/networking/proxies-forward-reverse/index.html" => [
      "env | grep -i proxy",
      "curl -v --proxy http://proxy.example:3128 https://example.com/",
      "curl -v --noproxy '*' https://example.com/",
      "openssl s_client -proxy proxy.example:3128 -connect example.com:443 -servername example.com",
      "dig proxy.example",
      "tcpdump -nn -i any host proxy.example"
    ],
    "docs/kubernetes/storage-upgrades/index.html" => [
      "kubectl version",
      "kubectl get nodes -o wide",
      "kubectl get pods -A -o wide",
      "kubectl get apiservices",
      "kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration",
      "kubectl get pdb -A",
      "kubectl get deployment,daemonset,statefulset -A",
      "kubeadm upgrade plan"
    ],
    "docs/ceph/index.html" => [
      "ceph -s",
      "ceph health detail",
      "ceph osd tree",
      "ceph osd df tree",
      "ceph pg stat",
      "ceph pg dump_stuck",
      "ceph df"
    ],
    "docs/ceph/rook-ceph/index.html" => [
      "kubectl -n rook-ceph get cephcluster",
      "kubectl -n rook-ceph describe cephcluster rook-ceph",
      "kubectl -n rook-ceph get pods -o wide",
      "kubectl -n rook-ceph get cephblockpool,cephfilesystem,cephobjectstore",
      "kubectl get storageclass"
    ],
    "docs/ceph/rados-crush-placement/index.html" => [
      "ceph osd lspools",
      "ceph osd pool ls detail",
      "ceph osd pool get <pool> all",
      "ceph osd crush tree",
      "ceph osd crush rule ls",
      "ceph osd crush rule dump <rule>",
      "ceph pg dump pgs_brief",
      "ceph pg map <pool>.<object-or-pgid>",
      "ceph pg <pgid> query"
    ],
    "docs/ceph/block-file-object/index.html" => [
      "rbd pool init <pool>",
      "rbd create <pool>/<image> --size 100G",
      "rbd info <pool>/<image>",
      "rbd status <pool>/<image>",
      "rbd snap create <pool>/<image>@before-change",
      "rbd snap ls <pool>/<image>",
      "rbd du <pool>/<image>",
      "rbd perf image iostat"
    ],
    "docs/ceph/operations-recovery/index.html" => [
      "ceph -s",
      "ceph health detail",
      "ceph versions",
      "ceph mon stat",
      "ceph mgr stat",
      "ceph osd stat",
      "ceph osd tree",
      "ceph osd df tree",
      "ceph pg stat",
      "ceph pg dump_stuck"
    ],
    "docs/ceph/performance-capacity/index.html" => [
      "ceph osd perf",
      "ceph osd df tree",
      "ceph osd pool stats",
      "ceph tell osd.* perf dump",
      "ceph daemon osd.<id> perf dump",
      "ceph health detail"
    ],
    "docs/istio/index.html" => [
      "istioctl version",
      "istioctl proxy-status",
      "istioctl analyze --all-namespaces",
      "kubectl get pods -n istio-system",
      "kubectl get gateway,virtualservice,destinationrule --all-namespaces",
      "kubectl get peerauthentication,authorizationpolicy --all-namespaces"
    ],
    "docs/istio/service-mesh/index.html" => [
      "istioctl proxy-status",
      "istioctl proxy-config routes <pod> -n <namespace>",
      "istioctl proxy-config clusters <pod> -n <namespace>",
      "istioctl ztunnel-config workloads -n <namespace>",
      "kubectl logs -n istio-system deploy/istiod",
      "kubectl logs -n istio-system -l app=ztunnel"
    ],
    "docs/istio/traffic-management/index.html" => [
      "kubectl get virtualservice,destinationrule,gateway,serviceentry --all-namespaces",
      "istioctl analyze --all-namespaces",
      "istioctl proxy-config routes <pod> -n <namespace>",
      "istioctl proxy-config clusters <pod> -n <namespace>",
      "istioctl proxy-config endpoints <pod> -n <namespace>"
    ],
    "docs/istio/security-mtls-policy/index.html" => [
      "kubectl get peerauthentication --all-namespaces",
      "istioctl authn tls-check <pod>.<namespace>",
      "istioctl proxy-config secret <pod> -n <namespace>",
      "istioctl proxy-config cluster <pod> -n <namespace> --fqdn <service>.<namespace>.svc.cluster.local"
    ],
    "docs/istio/gateways-ingress-egress/index.html" => [
      "kubectl get svc,pod -n istio-system",
      "kubectl get gateway,virtualservice --all-namespaces",
      "kubectl get httproute,gateway --all-namespaces",
      "istioctl proxy-config listeners deploy/<gateway-deploy> -n istio-system",
      "istioctl proxy-config routes deploy/<gateway-deploy> -n istio-system"
    ],
    "docs/istio/zero-downtime-upgrades/index.html" => [
      "istioctl version",
      "istioctl x precheck",
      "istioctl analyze --all-namespaces",
      "istioctl proxy-status",
      "kubectl get pods -n istio-system -o wide",
      "kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration",
      "kubectl get ns -L istio-injection,istio.io/rev,istio.io/dataplane-mode",
      "kubectl get pdb --all-namespaces"
    ],
    "docs/istio/observability-troubleshooting/index.html" => [
      "istioctl version",
      "istioctl proxy-status",
      "istioctl analyze --all-namespaces",
      "istioctl proxy-config listeners <pod> -n <namespace>",
      "istioctl proxy-config routes <pod> -n <namespace>",
      "istioctl proxy-config clusters <pod> -n <namespace>",
      "istioctl proxy-config endpoints <pod> -n <namespace>",
      "istioctl proxy-config secret <pod> -n <namespace>",
      "kubectl logs -n istio-system deploy/istiod"
    ],
    "docs/databases/postgres/index.html" => [
      "psql -d <database>",
      "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM table_name;",
      "VACUUM (ANALYZE) table_name;"
    ],
    "docs/databases/postgres/operations-ha/index.html" => [
      "psql -d <database> -c \"SELECT pid, state, wait_event_type, wait_event, now() - query_start AS age, query FROM pg_stat_activity ORDER BY query_start NULLS LAST LIMIT 20;\"",
      "psql -d <database> -c \"SELECT * FROM pg_stat_replication;\"",
      "psql -d <database> -c \"SELECT slot_name, active, restart_lsn, wal_status FROM pg_replication_slots;\"",
      "psql -d <database> -c \"SELECT * FROM pg_stat_archiver;\"",
      "psql -d <database> -c \"SELECT checkpoints_timed, checkpoints_req, buffers_checkpoint FROM pg_stat_checkpointer;\"",
      "psql -d <database> -c \"SELECT wal_records, wal_fpi, wal_bytes FROM pg_stat_wal;\"",
      "psql -d <database> -c \"SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), now() - pg_last_xact_replay_timestamp() AS replay_delay;\"",
      "psql -d <database> -c \"SELECT subname, subenabled, subfailover FROM pg_subscription;\""
    ],
    "docs/databases/postgres/zero-downtime-upgrades/index.html" => [
      "kubectl get clusters.postgresql.cnpg.io,pods,pvc,svc -A",
      "kubectl cnpg status <cluster> -n <namespace>",
      "kubectl get pdb -A",
      "kubectl get events -n <namespace> --sort-by=.lastTimestamp",
      "psql -d <database> -c \"SHOW server_version;\"",
      "psql -d <database> -c \"SELECT * FROM pg_stat_replication;\"",
      "psql -d <database> -c \"SELECT slot_name, active, restart_lsn, wal_status, safe_wal_size FROM pg_replication_slots;\"",
      "psql -d <database> -c \"SELECT subname, subenabled, subfailover FROM pg_subscription;\"",
      "psql -d <database> -c \"SELECT schemaname, sequencename, last_value FROM pg_sequences ORDER BY 1, 2 LIMIT 20;\""
    ],
    "docs/databases/postgres/pgbouncer/index.html" => [
      "psql \"postgresql://<user>@<pgbouncer-host>:6432/pgbouncer\" -c \"SHOW POOLS;\"",
      "psql \"postgresql://<user>@<pgbouncer-host>:6432/pgbouncer\" -c \"SHOW STATS;\"",
      "psql \"postgresql://<user>@<pgbouncer-host>:6432/pgbouncer\" -c \"SHOW CLIENTS;\"",
      "psql \"postgresql://<user>@<pgbouncer-host>:6432/pgbouncer\" -c \"SHOW SERVERS;\"",
      "psql \"postgresql://<user>@<pgbouncer-host>:6432/pgbouncer\" -c \"SHOW DATABASES;\"",
      "psql \"postgresql://<user>@<pgbouncer-host>:6432/pgbouncer\" -c \"SHOW CONFIG;\""
    ],
    "docs/databases/postgres/cloudnativepg/index.html" => [
      "kubectl -n cnpg-system get deploy,pod,svc",
      "kubectl -n cnpg-system describe deploy cnpg-controller-manager",
      "kubectl -n cnpg-system scale deploy cnpg-controller-manager --replicas=2",
      "kubectl -n cnpg-system rollout status deploy cnpg-controller-manager",
      "kubectl -n cnpg-system logs deploy/cnpg-controller-manager --tail=100",
      "kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration | grep -i cnpg"
    ],
    "docs/databases/opensearch/index.html" => [
      "curl -sS https://<opensearch>:9200/_cluster/health?pretty",
      "curl -sS https://<opensearch>:9200/_cat/nodes?v",
      "curl -sS https://<opensearch>:9200/_cat/shards?v",
      "curl -sS https://<opensearch>:9200/_cluster/allocation/explain?pretty -H 'Content-Type: application/json' -d '{}'",
      "curl -sS https://<opensearch>:9200/_cat/indices?v",
      "curl -sS https://<opensearch>:9200/_plugins/_replication/<follower-index>/_status?pretty"
    ]
  }.freeze

  def site_path(relative_path)
    File.join(ROOT, "_site", relative_path)
  end

  def read_site(relative_path)
    File.read(site_path(relative_path))
  end

  def first_command_block(html)
    html[%r{<div class="language-bash highlighter-rouge">.*?</code>}m]
  end

  def text_content(html)
    CGI.unescapeHTML(html.gsub(/<[^>]+>/, ""))
  end

  def test_expected_pages_exist
    COMMAND_BLOCKS.keys.each do |relative_path|
      assert_path_exists site_path(relative_path)
    end
  end

  def test_command_blocks_keep_each_command_on_its_own_line
    COMMAND_BLOCKS.each do |relative_path, expected_lines|
      block = first_command_block(read_site(relative_path))

      refute_nil block, "Expected a bash command block in #{relative_path}"
      assert_includes block, "\n", "Expected command block markup to preserve newlines in #{relative_path}"
      assert_equal expected_lines, text_content(block).lines.map(&:strip).reject(&:empty?)
    end
  end

  def test_command_blocks_are_not_collapsed_into_single_lines
    block = first_command_block(read_site("docs/kubernetes/troubleshooting/index.html"))

    refute_includes text_content(block), "kubectl get nodes kubectl get pods"
    assert_includes text_content(block), "kubectl get nodes\nkubectl get pods"
  end

  def test_command_block_alignment_css_is_present
    html = read_site("docs/kubernetes/troubleshooting/index.html")
    css = read_site("assets/css/study.css")

    assert_includes html, 'class="language-bash highlighter-rouge"'
    assert_includes html, '<pre class="highlight"><code>'
    assert_includes css, "white-space: pre"
    assert_includes css, ".highlight .k"
    assert_includes css, ".highlight pre"
  end

  def test_local_study_assets_replace_third_party_theme
    html = read_site("index.html")
    config = File.read(File.join(ROOT, "_config.yml"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))

    refute_includes config, "theme: jekyll-theme-chirpy"
    refute_includes gemfile, "jekyll-theme-chirpy"
    refute_includes html, "jekyll-theme-chirpy"
    assert_includes html, "/assets/css/study.css"
    assert_includes html, "/assets/js/study.js"
    assert_includes html, "Tech Study Guide"
    refute_includes config, "theme_name:"
  end

  def test_github_pages_workflow_builds_project_pages_site
    config = YAML.load_file(File.join(ROOT, "_config.yml"))
    workflow_path = File.join(ROOT, ".github/workflows/pages.yml")
    workflow_text = File.read(workflow_path)
    workflow = YAML.load_file(workflow_path)
    build_steps = workflow.fetch("jobs").fetch("build").fetch("steps")
    deploy_steps = workflow.fetch("jobs").fetch("deploy").fetch("steps")
    build_command = build_steps.find { |step| step["name"] == "Build with Jekyll" }.fetch("run")
    action_refs = (build_steps + deploy_steps).filter_map { |step| step["uses"] }

    assert_equal "https://pbsladek.github.io", config.fetch("url")
    assert_equal "", config.fetch("baseurl")
    assert_includes action_refs, "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
    assert_includes action_refs, "ruby/setup-ruby@afeafc3d1ab54a631816aba4c914a0081c12ff2f"
    assert_includes action_refs, "actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b"
    assert_includes action_refs, "actions/upload-pages-artifact@56afc609e74202658d3ffba0e8f6dda462b719fa"
    assert_includes action_refs, "actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e"
    action_refs.each do |action_ref|
      assert_match %r{\A[^@\s]+@[0-9a-f]{40}\z}, action_ref
    end
    assert_includes build_command, '--baseurl "${{ steps.pages.outputs.base_path }}"'
    refute_includes workflow_text, "secrets.GITHUB_TOKEN"
  end

  def test_local_secret_files_are_ignored
    gitignore = File.read(File.join(ROOT, ".gitignore"))
    dockerignore = File.read(File.join(ROOT, ".dockerignore"))

    [gitignore, dockerignore].each do |ignore_file|
      assert_includes ignore_file, ".env"
      assert_includes ignore_file, ".env.*"
      assert_includes ignore_file, "*.pem"
      assert_includes ignore_file, "*.key"
      assert_includes ignore_file, "id_rsa"
    end
  end

  def test_sidebar_navigation_theme_toggle_and_reader_controls_render
    html = read_site("docs/databases/postgres/index.html")

    assert_includes html, 'class="site-sidebar"'
    assert_includes html, 'class="study-nav"'
    assert_includes html, 'class="nav-section nav-meta"'
    assert_includes html, "Study Tools"
    assert_includes html, "<summary>"
    assert_includes html, 'href="/docs/databases/postgres/"'
    assert_includes html, 'data-action="collapse-sidebar"'
    assert_includes html, 'data-sidebar-toggle'
    assert_includes html, 'aria-controls="site-sidebar"'
    assert_includes html, ">Hide nav</button>"
    assert_includes html, 'data-action="toggle-sidebar"'
    assert_includes html, 'id="mode-toggle"'
    assert_includes html, 'data-action="toggle-reader"'
    assert_includes html, 'data-action="mark-complete"'
    assert_includes html, 'data-page-complete-status'
    refute_includes html, 'data-action="toggle-runbook"'
    refute_includes html, "Highlight runbook steps"
    assert_includes html, 'data-action="copy-page-link"'
    assert_includes html, 'data-action="open-study"'
    assert_includes html, 'id="study-mode-toggle"'
    assert_includes html, 'id="font-family-control"'
    assert_includes html, 'id="text-size-control"'
    assert_includes html, 'id="page-toc"'
    assert_includes html, 'class="related-pages"'
    assert_includes html, 'class="nav-neighbors"'
    assert_includes html, 'id="study-weak-only"'
    assert_includes html, 'id="study-missed-only"'
    assert_includes html, 'assets/js/mermaid.min.js'
    assert_includes html, 'localStorage.getItem("theme")'
    assert_includes html, 'localStorage.getItem("sidebarState")'
    assert_operator html.index('localStorage.getItem("theme")'), :<, html.index('assets/css/study.css')
    assert_includes html, 'html[data-theme="dark"]'
    assert_includes html, 'document.documentElement.dataset.sidebarState'

    study_tools = html.index("Study Tools")
    refute_nil study_tools
    assert_operator html.index("<summary>Troubleshooting</summary>"), :<, study_tools
    assert_operator html.index(">Knowledge Graph</a>", study_tools), :>, study_tools
    assert_operator html.index(">Tags</a>", study_tools), :>, study_tools
    assert_operator html.index(">Cross-Topic Study Paths</a>", study_tools), :>, study_tools
    assert_operator html.index(">Foundational Study Review</a>", study_tools), :>, study_tools
    assert_operator html.index(">Glossary</a>", study_tools), :>, study_tools
    assert_operator html.index(">Scenario Labs</a>", study_tools), :>, study_tools
  end

  def test_ceph_and_istio_have_expanded_subpage_navigation
    nav = YAML.load_file(File.join(ROOT, "_data/study_nav.yml"))
    ceph = nav.find { |item| item.fetch("title") == "Ceph" }
    istio = nav.find { |item| item.fetch("title") == "Istio" }

    refute_nil ceph
    refute_nil istio

    ceph_subpages = ceph.fetch("children").reject { |item| item.fetch("title") == "Overview" }
    istio_subpages = istio.fetch("children").reject { |item| item.fetch("title") == "Overview" }

    assert_operator ceph_subpages.length, :>=, 4
    assert_operator istio_subpages.length, :>=, 4

    ceph_subpages.each do |item|
      html_path = item.fetch("url").sub(%r{\A/}, "").sub(%r{/\z}, "/index.html")
      assert_includes read_site(html_path), 'class="study-card-grid"', "Expected study cards for #{item.fetch("url")}"
    end

    istio_subpages.each do |item|
      html_path = item.fetch("url").sub(%r{\A/}, "").sub(%r{/\z}, "/index.html")
      assert_includes read_site(html_path), 'class="study-card-grid"', "Expected study cards for #{item.fetch("url")}"
    end
  end

  def test_navigation_supports_topic_embedded_examples_and_postgres_groups
    nav = YAML.load_file(File.join(ROOT, "_data/study_nav.yml"))
    databases = nav.find { |item| item.fetch("title") == "Databases" }
    postgres = databases.fetch("children").find { |item| item.fetch("title") == "PostgreSQL" }
    networking = nav.find { |item| item.fetch("title") == "Networking" }
    troubleshooting = nav.find { |item| item.fetch("title") == "Troubleshooting" }

    assert_nil nav.find { |item| item.fetch("title") == "Practical Examples" }
    refute_nil databases
    refute_nil postgres
    refute_nil networking
    refute_nil troubleshooting
    refute_nil nav.find { |item| item.fetch("title") == "Cross-Topic Study Paths" }
    refute_nil nav.find { |item| item.fetch("title") == "Glossary" }

    ["Linux", "DNS", "Networking", "Kubernetes", "Identity and Access", "Databases", "Ceph", "Istio", "Troubleshooting"].each do |title|
      section = nav.find { |item| item.fetch("title") == title }
      refute_nil section
      refute section.fetch("children").any? { |item| item.fetch("title") == "Practical Examples" }, "Expected practical examples to be embedded in topic pages under #{title}"
    end

    ["Request Path", "Cross-Layer Incident Runbooks", "Datacenter L2/L3 Operations", "Resilience, Timeouts, and Draining", "Zero-Trust Networking"].each do |title|
      assert networking.fetch("children").any? { |item| item.fetch("title") == title }, "Expected Networking nav to include #{title}"
    end
    assert troubleshooting.fetch("children").any? { |item| item.fetch("title") == "Incident Entry Points" }

    assert_operator postgres.fetch("children").length, :>=, 4

    html = read_site("docs/databases/postgres/cloudnativepg/index.html")
    assert_includes html, "nav-level-2"
    assert_includes html, "nav-level-3"
    assert_includes html, "Zero-Downtime Upgrades"

    graph = read_site("knowledge-graph/index.html")
    assert_includes graph, "Request Path"
    assert_includes graph, "Cross-Layer Incident Runbooks"
    assert_includes graph, "Incident Entry Points"
    refute_includes graph, 'data-graph-cluster="cross-topic-study-paths"'
    refute_includes graph, 'data-graph-cluster="glossary"'
    assert_includes graph, "Datacenter L2/L3 Operations"
    assert_includes graph, "Resilience, Timeouts, and Draining"
    assert_includes graph, "Zero-Trust Networking"
    assert_includes graph, "Zero-Downtime Upgrades"
  end

  def test_search_index_contains_pages_tags_and_content
    index = JSON.parse(read_site("assets/js/search-index.json"))
    databases = index.find { |item| item["title"] == "Databases" }
    postgres = index.find { |item| item["title"] == "PostgreSQL" }
    postgres_ops = index.find { |item| item["title"] == "PostgreSQL Operations, HA, Replication, and Recovery" }
    postgres_upgrades = index.find { |item| item["title"] == "PostgreSQL Zero-Downtime Upgrades on Kubernetes" }
    pgbouncer = index.find { |item| item["title"] == "PgBouncer" }
    opensearch = index.find { |item| item["title"] == "OpenSearch Operations, Replication, Sharding, and HA" }
    troubleshooting = index.find { |item| item["title"] == "Troubleshooting and Error Handling" }
    incident_entrypoints = index.find { |item| item["title"] == "Incident Entry Points" }
    foundational_review = index.find { |item| item["title"] == "Foundational Study Review" }
    study_paths = index.find { |item| item["title"] == "Cross-Topic Study Paths" }
    glossary = index.find { |item| item["title"] == "Glossary" }
    practical_linux = index.find { |item| item["title"] == "Linux Operations Examples" }
    linux_ebpf = index.find { |item| item["title"] == "Linux eBPF and Tracing" }
    linux_memory = index.find { |item| item["title"] == "Linux Memory Pressure and OOM" }
    linux_syscalls = index.find { |item| item["title"] == "Linux System Call Debugging" }
    linux_security = index.find { |item| item["title"] == "Linux Security Controls" }
    linux_recovery = index.find { |item| item["title"] == "Linux Package and Boot Recovery" }
    linux_perf_runbooks = index.find { |item| item["title"] == "Linux Performance Triage Runbooks" }
    practical_dns = index.find { |item| item["title"] == "DNS Examples" }
    practical_network = index.find { |item| item["title"] == "Networking TLS and mTLS Examples" }
    practical_kubernetes = index.find { |item| item["title"] == "Kubernetes Examples" }
    practical_identity = index.find { |item| item["title"] == "Identity Examples" }
    practical_databases = index.find { |item| item["title"] == "Database and Search Examples" }
    practical_ceph = index.find { |item| item["title"] == "Ceph Storage Examples" }
    practical_istio = index.find { |item| item["title"] == "Istio Service Mesh Examples" }
    practical_troubleshooting = index.find { |item| item["title"] == "Troubleshooting Examples" }
    ceph = index.find { |item| item["title"] == "Ceph" }
    lvm = index.find { |item| item["title"] == "Linux LVM" }
    systemd = index.find { |item| item["title"] == "systemd" }
    resolv = index.find { |item| item["title"] == "resolv.conf" }
    boot = index.find { |item| item["title"] == "Linux Boot and Userspace" }
    network_boot = index.find { |item| item["title"] == "Network Boot and Automated Provisioning" }
    kernel_modules_devices = index.find { |item| item["title"] == "Linux Kernel Modules and Devices" }
    filesystems = index.find { |item| item["title"] == "Linux Filesystems and IO" }
    block_devices = index.find { |item| item["title"] == "Linux Block Devices and Partitioning" }
    mounts = index.find { |item| item["title"] == "Linux Mounts and fstab" }
    mount_namespaces = index.find { |item| item["title"] == "Linux Mount Namespaces and Propagation" }
    ext4_xfs = index.find { |item| item["title"] == "ext4, XFS, and Filesystem Repair" }
    storage_drives_raid_db = index.find { |item| item["title"] == "Storage Drives, RAID, and Database Performance" }
    raid_multipath = index.find { |item| item["title"] == "RAID, Multipath, and Device Mapper" }
    storage_health = index.find { |item| item["title"] == "Linux Storage Health and Performance" }
    containerization_oci_vms = index.find { |item| item["title"] == "Containerization, OCI, and VMs" }
    linux_network = index.find { |item| item["title"] == "Linux Network Stack" }
    kernel_network_performance = index.find { |item| item["title"] == "Linux Kernel Network Performance" }
    tcp_kernel_tuning = index.find { |item| item["title"] == "Linux TCP Kernel Tuning" }
    sockets_ipc = index.find { |item| item["title"] == "Linux Sockets and IPC" }
    processes_threads = index.find { |item| item["title"] == "Linux Processes and Threads" }
    users_permissions = index.find { |item| item["title"] == "Users, Permissions, and sudo" }
    ssh_access = index.find { |item| item["title"] == "SSH Access" }
    logs = index.find { |item| item["title"] == "Logs and Observability" }
    scheduled = index.find { |item| item["title"] == "Scheduled Automation" }
    backup_transfer = index.find { |item| item["title"] == "Linux Backup and File Transfer" }
    time_hostname = index.find { |item| item["title"] == "Time, Hostname, and Identity" }
    gpu_drivers = index.find { |item| item["title"] == "Linux GPU Drivers" }
    systemd_networking = index.find { |item| item["title"] == "systemd Networking" }
    systemd_socket_network = index.find { |item| item["title"] == "systemd Socket Activation and Network Services" }
    dns_overview = index.find { |item| item["title"] == "DNS" && item["url"] == "/docs/dns/" }
    dns_cache = index.find { |item| item["title"] == "DNS Resolution and Caching" }
    zones = index.find { |item| item["title"] == "Authoritative DNS and Zones" }
    dnssec = index.find { |item| item["title"] == "DNSSEC and DNS Privacy" }
    dns_records = index.find { |item| item["title"] == "DNS Records, Responses, and Transport" }
    request_path = index.find { |item| item["title"] == "Request Path" }
    packet_path = index.find { |item| item["title"] == "Packet Path" }
    cross_layer_runbooks = index.find { |item| item["title"] == "Cross-Layer Incident Runbooks" }
    packet_capture = index.find { |item| item["title"] == "Packet Capture and Analysis" }
    routing = index.find { |item| item["title"] == "Routing, NAT, and Firewalls" }
    bgp = index.find { |item| item["title"] == "BGP and Dynamic Routing" }
    datacenter_l2_l3 = index.find { |item| item["title"] == "Datacenter L2/L3 Operations" }
    cloud_networking = index.find { |item| item["title"] == "Cloud Networking" }
    network_namespaces = index.find { |item| item["title"] == "Network Namespaces and Virtual Networking" }
    ipv6_operations = index.find { |item| item["title"] == "IPv6 Operations" }
    nat_gateways = index.find { |item| item["title"] == "NAT Gateways and Network Address Translation" }
    firewall_netfilter = index.find { |item| item["title"] == "Firewalls, iptables, and Netfilter" }
    vpn_ipsec = index.find { |item| item["title"] == "VPNs and IPsec Tunnels" }
    dhcp_routers_switches = index.find { |item| item["title"] == "DHCP, Routers, and Switches" }
    switching = index.find { |item| item["title"] == "Switching, VLANs, and Hosts" }
    ip_addressing = index.find { |item| item["title"] == "IP Addressing and Subnetting" }
    icmp_mtu = index.find { |item| item["title"] == "ICMP, MTU, and Path Testing" }
    certificates = index.find { |item| item["title"] == "Certificates and HTTPS" }
    tcp_sockets = index.find { |item| item["title"] == "TCP and Sockets" }
    udp_quic = index.find { |item| item["title"] == "UDP, QUIC, and Connectionless Traffic" }
    load_balancers = index.find { |item| item["title"] == "Load Balancers and Proxies" }
    resilience_timeouts = index.find { |item| item["title"] == "Resilience, Timeouts, and Draining" }
    forward_reverse_proxies = index.find { |item| item["title"] == "Forward and Reverse Proxies" }
    http_proxy_debugging = index.find { |item| item["title"] == "HTTP and Proxy Debugging" }
    zero_trust_networking = index.find { |item| item["title"] == "Zero-Trust Networking" }
    tcp_tls = index.find { |item| item["title"] == "TCP, TLS, and HTTP" }
    k8s_core = index.find { |item| item["title"] == "Core Concepts" }
    k8s_networking = index.find { |item| item["title"] == "Kubernetes Networking" }
    k8s_troubleshooting = index.find { |item| item["title"] == "Troubleshooting" && item["url"] == "/docs/kubernetes/troubleshooting/" }
    k8s_dns = index.find { |item| item["title"] == "Kubernetes DNS and CoreDNS" }
    k8s_nats_dns = index.find { |item| item["title"] == "NATS, DNS, and Kubernetes Networking" }
    k8s_external_dns = index.find { |item| item["title"] == "Kubernetes ExternalDNS" }
    k8s_services = index.find { |item| item["title"] == "Kubernetes Services and EndpointSlices" }
    k8s_pod_networking = index.find { |item| item["title"] == "Kubernetes Pod Networking and CNI" }
    k8s_network_policy = index.find { |item| item["title"] == "Kubernetes NetworkPolicy" }
    k8s_ingress_gateway = index.find { |item| item["title"] == "Kubernetes Ingress, Gateway, and Load Balancers" }
    k8s_storage_upgrades = index.find { |item| item["title"] == "Kubernetes Storage and Upgrades" }
    identity = index.find { |item| item["title"] == "Identity and Access" }
    auth_protocols = index.find { |item| item["title"] == "IdP, SAML, JWT, OAuth, and OIDC" }
    domain_controllers = index.find { |item| item["title"] == "Domain Controllers and Directory DNS" }
    debian = index.find { |item| item["title"] == "Debian and Ubuntu Operations" }
    istio = index.find { |item| item["title"] == "Istio" }
    service_mesh = index.find { |item| item["title"] == "Istio Service Mesh" }
    istio_traffic = index.find { |item| item["title"] == "Istio Traffic Management" }
    istio_security = index.find { |item| item["title"] == "Istio Security, mTLS, and Policy" }
    istio_gateways = index.find { |item| item["title"] == "Istio Gateways, Ingress, and Egress" }
    istio_zero_downtime = index.find { |item| item["title"] == "Istio Zero Downtime Upgrades on Kubernetes" }
    istio_observability = index.find { |item| item["title"] == "Istio Observability and Troubleshooting" }
    ceph_rados = index.find { |item| item["title"] == "Ceph RADOS, CRUSH, and Placement" }
    ceph_interfaces = index.find { |item| item["title"] == "Ceph Block, File, and Object Interfaces" }
    ceph_operations = index.find { |item| item["title"] == "Ceph Operations and Recovery" }
    ceph_performance = index.find { |item| item["title"] == "Ceph Performance and Capacity" }

    refute_nil databases
    refute_nil postgres
    refute_nil postgres_ops
    refute_nil postgres_upgrades
    refute_nil pgbouncer
    refute_nil opensearch
    refute_nil troubleshooting
    refute_nil incident_entrypoints
    refute_nil foundational_review
    refute_nil study_paths
    refute_nil glossary
    assert_nil index.find { |item| item["title"] == "Practical Examples" }
    refute_nil practical_linux
    refute_nil linux_ebpf
    refute_nil linux_memory
    refute_nil linux_syscalls
    refute_nil linux_security
    refute_nil linux_recovery
    refute_nil linux_perf_runbooks
    refute_nil practical_dns
    refute_nil practical_network
    refute_nil practical_kubernetes
    refute_nil practical_identity
    refute_nil practical_databases
    refute_nil practical_ceph
    refute_nil practical_istio
    refute_nil practical_troubleshooting
    refute_nil ceph
    refute_nil lvm
    refute_nil systemd
    refute_nil resolv
    refute_nil boot
    refute_nil network_boot
    refute_nil kernel_modules_devices
    refute_nil filesystems
    refute_nil block_devices
    refute_nil mounts
    refute_nil mount_namespaces
    refute_nil ext4_xfs
    refute_nil storage_drives_raid_db
    refute_nil raid_multipath
    refute_nil storage_health
    refute_nil containerization_oci_vms
    refute_nil linux_network
    refute_nil kernel_network_performance
    refute_nil tcp_kernel_tuning
    refute_nil sockets_ipc
    refute_nil processes_threads
    refute_nil users_permissions
    refute_nil ssh_access
    refute_nil logs
    refute_nil scheduled
    refute_nil backup_transfer
    refute_nil time_hostname
    refute_nil gpu_drivers
    refute_nil systemd_networking
    refute_nil systemd_socket_network
    refute_nil dns_overview
    refute_nil dns_cache
    refute_nil zones
    refute_nil dnssec
    refute_nil dns_records
    refute_nil request_path
    refute_nil packet_path
    refute_nil cross_layer_runbooks
    refute_nil packet_capture
    refute_nil routing
    refute_nil bgp
    refute_nil datacenter_l2_l3
    refute_nil cloud_networking
    refute_nil network_namespaces
    refute_nil ipv6_operations
    refute_nil nat_gateways
    refute_nil firewall_netfilter
    refute_nil vpn_ipsec
    refute_nil dhcp_routers_switches
    refute_nil switching
    refute_nil ip_addressing
    refute_nil icmp_mtu
    refute_nil certificates
    refute_nil tcp_sockets
    refute_nil udp_quic
    refute_nil load_balancers
    refute_nil resilience_timeouts
    refute_nil forward_reverse_proxies
    refute_nil http_proxy_debugging
    refute_nil zero_trust_networking
    refute_nil tcp_tls
    refute_nil k8s_core
    refute_nil k8s_networking
    refute_nil k8s_troubleshooting
    refute_nil k8s_dns
    refute_nil k8s_nats_dns
    refute_nil k8s_external_dns
    refute_nil k8s_services
    refute_nil k8s_pod_networking
    refute_nil k8s_network_policy
    refute_nil k8s_ingress_gateway
    refute_nil k8s_storage_upgrades
    refute_nil identity
    refute_nil auth_protocols
    refute_nil domain_controllers
    refute_nil debian
    refute_nil istio
    refute_nil service_mesh
    refute_nil istio_traffic
    refute_nil istio_security
    refute_nil istio_gateways
    refute_nil istio_zero_downtime
    refute_nil istio_observability
    refute_nil ceph_rados
    refute_nil ceph_interfaces
    refute_nil ceph_operations
    refute_nil ceph_performance
    assert_includes postgres["tags"], "databases"
    assert_includes postgres["content"], "PgBouncer"
    assert_includes postgres["content"], "MVCC Snapshot Timeline"
    assert_includes postgres["content"], "Isolation examples"
    assert_includes postgres["content"], "Index design examples"
    assert_includes postgres_ops["content"], "managed HA"
    assert_includes postgres_ops["content"], "replication slots"
    assert_includes postgres_ops["content"], "HA Failover"
    assert_includes postgres_ops["content"], "Detect primary failure"
    assert_includes postgres_ops["content"], "Validate writes, WAL archive, backups"
    assert_includes postgres_ops["content"], "Split brain"
    assert_includes postgres_ops["content"], "Logical replication model"
    assert_includes postgres_ops["content"], "Logical failover"
    assert_includes postgres_ops["content"], "Sharding"
    assert_includes postgres_ops["content"], "shard key"
    assert_includes postgres_ops["content"], "postgres_fdw"
    assert_includes postgres_ops["content"], "PITR"
    assert_includes postgres_ops["content"], "pg_verifybackup"
    assert_includes postgres_ops["content"], "pg_dumpall"
    assert_includes postgres_ops["content"], "pg_locks"
    assert_includes postgres_ops["content"], "idle_in_transaction_session_timeout"
    assert_includes postgres_ops["content"], "remote_apply"
    assert_includes postgres_ops["content"], "High CPU"
    assert_includes postgres_ops["content"], "High RAM"
    assert_includes postgres_ops["content"], "Lock wait evidence path"
    assert_includes postgres_ops["content"], "Lock triage guardrails"
    assert_includes postgres_upgrades["tags"], "cloudnativepg"
    assert_includes postgres_upgrades["content"], "CloudNativePG Minor Updates"
    assert_includes postgres_upgrades["content"], "Blue/Green Logical Replication Runbook"
    assert_includes postgres_upgrades["content"], "pg_upgrade"
    assert_includes postgres_upgrades["content"], "PgBouncer and Connection Draining"
    assert_includes postgres_upgrades["content"], "Kubernetes Guardrails"
    assert_includes postgres_upgrades["content"], "sequences"
    assert_includes pgbouncer["content"], "transaction pooling"
    assert_includes pgbouncer["content"], "SHOW POOLS"
    assert_includes pgbouncer["content"], "cl_waiting"
    assert_includes pgbouncer["content"], "max_client_conn"
    assert_includes pgbouncer["content"], "server_reset_query"
    assert_includes pgbouncer["content"], "auth_query"
    cloudnativepg = index.find { |item| item["title"] == "CloudNativePG" }
    refute_nil cloudnativepg
    assert_includes cloudnativepg["content"], "Operator Deployment and Scaling"
    assert_includes cloudnativepg["content"], "Operator Upgrades"
    assert_includes cloudnativepg["content"], "leader election"
    assert_includes cloudnativepg["content"], "CLUSTERS_ROLLOUT_DELAY"
    assert_includes cloudnativepg["content"], "ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES"
    assert_includes k8s_storage_upgrades["content"], "Upgrade Inventory"
    assert_includes k8s_storage_upgrades["content"], "Version Skew and Order"
    assert_includes k8s_storage_upgrades["content"], "Worker Node Workflow"
    assert_includes k8s_storage_upgrades["content"], "Post-Upgrade Validation"
    assert_includes k8s_storage_upgrades["content"], "Managed Kubernetes"
    assert_includes opensearch["tags"], "opensearch"
    assert_includes opensearch["content"], "Cross-Cluster Replication"
    assert_includes opensearch["content"], "cluster-manager"
    assert_includes opensearch["content"], "primary shard"
    assert_includes opensearch["content"], "replica shard"
    assert_includes opensearch["content"], "allocation awareness"
    assert_includes opensearch["content"], "forced awareness"
    assert_includes opensearch["content"], "wait_for_active_shards"
    assert_includes opensearch["content"], "Snapshots and Recovery"
    assert_includes troubleshooting["content"], "CrashLoopBackOff"
    assert_includes troubleshooting["content"], "SQLSTATE"
    assert_includes troubleshooting["content"], "Universal Method"
    assert_includes troubleshooting["content"], "data plane"
    assert_includes troubleshooting["content"], "control plane"
    assert_includes incident_entrypoints["content"], "DNS works on node but not Pod"
    assert_includes incident_entrypoints["content"], "Large Payloads Hang"
    assert_includes incident_entrypoints["content"], "Intermittent 5xx"
    assert_includes foundational_review["content"], "Topic Coverage Matrix"
    assert_includes foundational_review["content"], "Big 101 Gaps"
    assert_includes foundational_review["content"], "data plane"
    assert_includes foundational_review["content"], "control plane"
    assert_includes foundational_review["content"], "stub resolvers"
    assert_includes foundational_review["content"], "JWT decoding"
    assert_includes foundational_review["content"], "RAID, replication, snapshots, and backups"
    assert_includes study_paths["content"], "Linux Foundations to Operations"
    assert_includes study_paths["content"], "Kubernetes Networking Incident Path"
    assert_includes study_paths["content"], "PostgreSQL Reliability and Zero Downtime"
    assert_includes study_paths["content"], "Production ML from 101 to Advanced Systems"
    assert_includes study_paths["content"], "Cross-Layer Incident Response"
    assert_includes glossary["content"], "conntrack"
    assert_includes glossary["content"], "EndpointSlice"
    assert_includes glossary["content"], "memory.high"
    assert_includes glossary["content"], "ALPN"
    assert_includes glossary["content"], "VXLAN"
    assert_includes systemd_networking["content"], "VLAN and Bridge Example"
    assert_includes firewall_netfilter["content"], "Host Firewall Example"
    assert_includes firewall_netfilter["content"], "nftables host policy"
    assert_includes linux_ebpf["content"], "tracepoints"
    assert_includes linux_ebpf["content"], "bpftrace"
    assert_includes linux_ebpf["content"], "XDP"
    assert_includes linux_ebpf["content"], "Symptom-driven one-liners"
    assert_includes linux_memory["content"], "OOM killer"
    assert_includes linux_memory["content"], "memory.events"
    assert_includes linux_memory["content"], "Pressure Stall Information"
    assert_includes linux_memory["content"], "OOM Comparison Matrix"
    assert_includes linux_memory["content"], "kubelet eviction"
    assert_includes linux_memory["content"], "Application heap OOM"
    assert_includes linux_memory["content"], "Runtime Memory Examples"
    assert_includes linux_memory["content"], "Java service"
    assert_includes linux_memory["content"], "Go service"
    assert_includes linux_syscalls["content"], "errno"
    assert_includes linux_syscalls["content"], "epoll_wait"
    assert_includes linux_syscalls["content"], "EINPROGRESS"
    assert_includes linux_syscalls["content"], "What strace Proves"
    assert_includes linux_syscalls["content"], "Annotated strace Output Gallery"
    assert_includes linux_syscalls["content"], "DNS Through strace"
    assert_includes linux_syscalls["content"], "Common Troubleshooting Recipes"
    assert_includes linux_syscalls["content"], "getsockopt(SO_ERROR)"
    assert_includes linux_security["content"], "seccomp"
    assert_includes linux_security["content"], "AppArmor"
    assert_includes linux_security["content"], "SELinux"
    assert_includes linux_recovery["content"], "GRUB rescue"
    assert_includes linux_recovery["content"], "update-initramfs"
    assert_includes linux_perf_runbooks["content"], "High Load, Low CPU"
    assert_includes linux_perf_runbooks["content"], "cgroup throttling"
    assert_includes dns_overview["content"], "Browser Enter-to-Answer Walkthrough"
    assert_includes dns_overview["content"], "Parse URL and check browser DNS/cache state"
    assert_includes dns_overview["content"], "OS and Stub Resolver Details"
    assert_includes dns_overview["content"], "Recursive Resolver Cache-Miss Traversal"
    assert_includes dns_overview["content"], "Root, TLD, and Authoritative Referrals"
    assert_includes dns_overview["content"], "Root referral"
    assert_includes dns_overview["content"], "Lame delegation"
    assert_includes dns_overview["content"], "query name minimization"
    assert_includes dns_overview["content"], "Address selection"
    assert_includes dns_overview["content"], "curl --resolve"
    assert_includes dns_overview["content"], "Per-link routing"
    assert_includes dns_overview["content"], "Referral anatomy"
    assert_includes dns_overview["content"], "Stub resolver behavior checklist"
    assert_includes dns_overview["content"], "Retry multiplication"
    assert_includes dns_overview["content"], "closest cached delegation"
    assert_includes dns_overview["content"], "Record type matters"
    assert_includes dns_overview["content"], "Parent-child delegation consistency"
    assert_includes dns_overview["content"], "additional section is not a source of arbitrary truth"
    assert_includes dns_overview["content"], "Anycast or geo DNS inconsistency"
    assert_includes dns_overview["content"], "A healthy authoritative server"
    assert_includes dns_cache["content"], "Intermittent DNS Runbook"
    assert_includes dns_cache["content"], "dig +tcp"
    assert_includes dns_cache["content"], "nslookup Deep Dive"
    assert_includes dns_cache["content"], "nslookup Output Interpretation"
    assert_includes dns_cache["content"], "nslookup Troubleshooting Workflows"
    assert_includes dns_cache["content"], "set vc"
    assert_includes cross_layer_runbooks["content"], "HTTP 504"
    assert_includes cross_layer_runbooks["content"], "Connection Refused"
    assert_includes cross_layer_runbooks["content"], "Connection Reset"
    assert_includes cross_layer_runbooks["content"], "TLS Timeout"
    assert_includes cross_layer_runbooks["content"], "DNS Intermittent"
    assert_includes cross_layer_runbooks["content"], "Large Requests Hang"
    assert_includes cross_layer_runbooks["content"], "Node Can Reach Service but Pod Cannot"
    assert_includes request_path["content"], "End-to-End Diagram"
    assert_includes request_path["content"], "DNS, client behavior"
    assert_includes request_path["content"], "Database"
    assert_includes request_path["content"], "Response Path"
    assert_includes k8s_networking["content"], "Service Datapath Modes"
    assert_includes k8s_networking["content"], "Service Datapath Diagrams"
    assert_includes k8s_networking["content"], "IPVS mode"
    assert_includes k8s_networking["content"], "eBPF replacement mode"
    assert_includes k8s_networking["content"], "allow-dns-egress"
    assert_includes k8s_pod_networking["content"], "Hairpin and SNAT Checks"
    assert_includes practical_identity["content"], "OAuth authorization-code token exchange"
    assert_includes practical_databases["content"], "CREATE INDEX CONCURRENTLY"
    assert_includes practical_databases["content"], "PgBouncer"
    assert_includes practical_databases["content"], "OpenSearch"
    assert_includes practical_ceph["content"], "ceph osd pool create"
    assert_includes practical_istio["content"], "VirtualService"
    assert_includes practical_istio["content"], "AuthorizationPolicy"
    assert_includes practical_troubleshooting["content"], "Troubleshooting Capture Example"
    assert_includes postgres["content"], "EXPLAIN"
    assert_includes databases["content"], "ACID"
    assert_includes databases["content"], "B-trees"
    assert_includes databases["content"], "Learning Path"
    assert_includes databases["content"], "Choosing the Right Tool Shape"
    assert_includes databases["content"], "replication not the same as backup"
    assert_includes ceph["content"], "RADOS"
    assert_includes ceph["content"], "Client IO Path"
    assert_includes ceph["content"], "Erasure-coded pool"
    assert_includes ceph_rados["content"], "PG autoscaler"
    assert_includes ceph_rados["content"], "Placement evidence"
    assert_includes ceph_rados["content"], "PG peering and recovery lifecycle"
    assert_includes ceph_interfaces["content"], "RBD"
    assert_includes ceph_operations["content"], "Recovery and Backfill"
    assert_includes ceph_operations["content"], "Recovery tuning decision matrix"
    assert_includes ceph_performance["content"], "BlueStore"
    assert_includes lvm["content"], "pvmove"
    assert_includes systemd["content"], "journalctl"
    assert_includes resolv["content"], "ndots"
    assert_includes boot["content"], "initramfs"
    assert_includes boot["content"], "EFI System Partition"
    assert_includes boot["content"], "systemd-boot"
    assert_includes network_boot["content"], "PXE"
    assert_includes network_boot["content"], "iPXE"
    assert_includes network_boot["content"], "ProxyDHCP"
    assert_includes network_boot["content"], "Ubuntu autoinstall"
    assert_includes network_boot["content"], "cloud-init NoCloud"
    assert_includes network_boot["content"], "Kickstart"
    assert_includes network_boot["content"], "reinstall loops"
    assert_includes kernel_modules_devices["content"], "modprobe"
    assert_includes kernel_modules_devices["content"], "modalias"
    assert_includes kernel_modules_devices["content"], "devtmpfs"
    assert_includes kernel_modules_devices["content"], "Secure Boot"
    assert_includes kernel_modules_devices["content"], "udev Rule Examples"
    assert_includes kernel_modules_devices["content"], "device rename failure cases"
    assert_includes filesystems["content"], "VFS"
    assert_includes block_devices["content"], "/dev/disk/by-id"
    assert_includes block_devices["content"], "PARTUUID"
    assert_includes block_devices["content"], "Typical GPT layout"
    assert_includes mounts["content"], "findmnt --verify"
    assert_includes mounts["content"], "systemd-fstab-generator"
    assert_includes mounts["content"], "x-systemd.device-timeout"
    assert_includes mounts["content"], "systemd Mount Dependency Examples"
    assert_includes mounts["content"], "RequiresMountsFor"
    assert_includes mount_namespaces["content"], "mountinfo"
    assert_includes mount_namespaces["content"], "Propagation Lab"
    assert_includes ext4_xfs["content"], "xfs_repair"
    assert_includes ext4_xfs["content"], "What Not To Do During Repair"
    assert_includes storage_drives_raid_db["content"], "SSD"
    assert_includes storage_drives_raid_db["content"], "HDD"
    assert_includes storage_drives_raid_db["content"], "RAID 0"
    assert_includes storage_drives_raid_db["content"], "RAID 10"
    assert_includes storage_drives_raid_db["content"], "RAID 0+1"
    assert_includes storage_drives_raid_db["content"], "write penalty"
    assert_includes storage_drives_raid_db["content"], "LVM With RAID"
    assert_includes storage_drives_raid_db["content"], "RAID vs LVM vs Filesystem"
    assert_includes storage_drives_raid_db["content"], "Physical disks / cloud volumes"
    assert_includes storage_drives_raid_db["content"], "Disk Failure Recovery"
    assert_includes storage_drives_raid_db["content"], "RAID Failure Modes"
    assert_includes storage_drives_raid_db["content"], "PostgreSQL Storage Mapping"
    assert_includes storage_drives_raid_db["content"], "PostgreSQL examples"
    assert_includes storage_drives_raid_db["content"], "Elasticsearch Storage Mapping"
    assert_includes storage_drives_raid_db["content"], "Elasticsearch examples"
    assert_includes raid_multipath["content"], "LUKS"
    assert_includes lvm["content"], "LVM and RAID"
    assert_includes storage_health["content"], "SMART"
    assert_includes storage_health["content"], "SMART and NVMe Interpretation Gallery"
    assert_includes storage_health["content"], "critical_warning"
    assert_includes containerization_oci_vms["content"], "OCI"
    assert_includes containerization_oci_vms["content"], "cgroups"
    assert_includes containerization_oci_vms["content"], "namespaces"
    assert_includes containerization_oci_vms["content"], "cgroup v2"
    assert_includes containerization_oci_vms["content"], "cpu.max"
    assert_includes containerization_oci_vms["content"], "memory.max"
    assert_includes containerization_oci_vms["content"], "memory.high"
    assert_includes containerization_oci_vms["content"], "Kubernetes Resource Mapping"
    assert_includes containerization_oci_vms["content"], "cgroup v2 Labs"
    assert_includes containerization_oci_vms["content"], "nr_throttled"
    assert_includes containerization_oci_vms["content"], "cpu.stat"
    assert_includes containerization_oci_vms["content"], "memory.events"
    assert_includes containerization_oci_vms["content"], "PSI"
    assert_includes containerization_oci_vms["content"], "pids.max"
    assert_includes containerization_oci_vms["content"], "overlayfs"
    assert_includes containerization_oci_vms["content"], "lowerdir"
    assert_includes containerization_oci_vms["content"], "upperdir"
    assert_includes containerization_oci_vms["content"], "copy-up"
    assert_includes containerization_oci_vms["content"], "whiteout"
    assert_includes containerization_oci_vms["content"], "network namespace"
    assert_includes containerization_oci_vms["content"], "veth pair"
    assert_includes containerization_oci_vms["content"], "Linux bridge"
    assert_includes containerization_oci_vms["content"], "docker0"
    assert_includes containerization_oci_vms["content"], "MASQUERADE"
    assert_includes containerization_oci_vms["content"], "DNAT"
    assert_includes containerization_oci_vms["content"], "conntrack"
    assert_includes containerization_oci_vms["content"], "macvlan"
    assert_includes containerization_oci_vms["content"], "ipvlan"
    assert_includes containerization_oci_vms["content"], "VXLAN"
    assert_includes containerization_oci_vms["content"], "KVM"
    assert_includes containerization_oci_vms["content"], "Hyper-V isolation"
    assert_includes containerization_oci_vms["content"], "Virtual Machine"
    assert_includes containerization_oci_vms["content"], "Security boundary layering"
    assert_includes linux_network["content"], "conntrack"
    assert_includes linux_network["content"], "Linux bridge"
    assert_includes linux_network["content"], "MASQUERADE"
    assert_includes linux_network["content"], "DNAT"
    assert_includes linux_network["content"], "Netfilter and routing lookup path"
    assert_includes kernel_network_performance["content"], "NAPI"
    assert_includes kernel_network_performance["content"], "RPS"
    assert_includes kernel_network_performance["content"], "Syscall-to-NIC Diagnostic Path"
    assert_includes kernel_network_performance["content"], "strace -ttT"
    assert_includes kernel_network_performance["content"], "ethtool -S"
    assert_includes kernel_network_performance["content"], "Queue and CPU steering map"
    assert_includes tcp_kernel_tuning["content"], "tcp_max_syn_backlog"
    assert_includes tcp_kernel_tuning["content"], "Backlog Saturation Lab"
    assert_includes tcp_kernel_tuning["content"], "ListenOverflows"
    assert_includes sockets_ipc["content"], "Unix domain sockets"
    assert_includes processes_threads["content"], "thread group"
    assert_includes users_permissions["content"], "visudo"
    assert_includes ssh_access["content"], "host keys"
    assert_includes logs["content"], "logrotate"
    assert_includes scheduled["content"], "systemd timers"
    assert_includes scheduled["content"], "Cronjobs"
    assert_includes scheduled["content"], "flock"
    assert_includes scheduled["content"], "anacron"
    assert_includes backup_transfer["content"], "rsync"
    assert_includes backup_transfer["content"], "--link-dest"
    assert_includes backup_transfer["content"], "Snapshot Backups"
    assert_includes backup_transfer["content"], "scp"
    assert_includes backup_transfer["content"], "Restore Runbook"
    assert_includes time_hostname["content"], "machine-id"
    assert_includes gpu_drivers["content"], "ROCm"
    assert_includes gpu_drivers["content"], "RADV"
    assert_includes gpu_drivers["content"], "nvidia-smi"
    assert_includes gpu_drivers["content"], "Secure Boot"
    assert_includes systemd_networking["content"], "network-online.target"
    assert_includes systemd_socket_network["content"], "ListenStream"
    assert_includes dns_cache["content"], "negative answer"
    assert_includes dns_cache["content"], "Stub, Recursive, and Authoritative"
    assert_includes dns_cache["content"], "Bailiwick"
    assert_includes dns_cache["content"], "glue"
    assert_includes zones["content"], "SOA serial"
    assert_includes dnssec["content"], "DNSKEY"
    assert_includes dns_records["content"], "NODATA"
    assert_includes dns_records["content"], "EDNS"
    assert_includes packet_path["content"], "qdisc"
    assert_includes packet_path["content"], "Production Packet-Capture Labs"
    assert_includes packet_path["content"], "MTU black hole"
    assert_includes packet_path["content"], "TLS SNI mismatch"
    assert_includes packet_path["content"], "DNS truncation"
    assert_includes packet_path["content"], "QUIC blocked"
    assert_includes packet_capture["content"], "tcpdump"
    assert_includes packet_capture["content"], "tcp.analysis.retransmission"
    assert_includes packet_capture["content"], "Packet-Capture Interpretation Gallery"
    assert_includes packet_capture["content"], "Wireshark Display-Filter Cheatsheet"
    assert_includes packet_capture["content"], "tls.handshake.extensions_server_name"
    assert_includes packet_capture["content"], "Rolling Captures"
    assert_includes routing["content"], "policy routing"
    assert_includes routing["content"], "Route Lookup and Policy Routing Example"
    assert_includes routing["content"], "Neighbor lookup"
    assert_includes bgp["content"], "AS path"
    assert_includes bgp["content"], "communities"
    assert_includes bgp["content"], "anycast"
    assert_includes bgp["content"], "Best-Path Walkthrough"
    assert_includes bgp["content"], "next hop reachable"
    assert_includes datacenter_l2_l3["content"], "LACP"
    assert_includes datacenter_l2_l3["content"], "MLAG"
    assert_includes datacenter_l2_l3["content"], "EVPN"
    assert_includes datacenter_l2_l3["content"], "Route dampening"
    assert_includes datacenter_l2_l3["content"], "EVPN/VXLAN Failure Map"
    assert_includes cloud_networking["content"], "security groups"
    assert_includes cloud_networking["content"], "Private endpoint"
    assert_includes cloud_networking["content"], "overlapping CIDRs"
    assert_includes cloud_networking["content"], "AWS, Azure, and Google Cloud Differences"
    assert_includes cloud_networking["content"], "Private Service Connect"
    assert_includes network_namespaces["content"], "veth pair"
    assert_includes network_namespaces["content"], "VXLAN"
    assert_includes network_namespaces["content"], "CNI"
    assert_includes ipv6_operations["content"], "Router Advertisements"
    assert_includes ipv6_operations["content"], "NAT64"
    assert_includes ipv6_operations["content"], "DNS64"
    assert_includes ipv6_operations["content"], "Router Advertisement and SLAAC flow"
    assert_includes ipv6_operations["content"], "NDP failure interpretation"
    assert_includes nat_gateways["content"], "port exhaustion"
    assert_includes nat_gateways["content"], "NAT Exhaustion Runbook"
    assert_includes nat_gateways["content"], "NAT Port Budget Estimator"
    assert_includes nat_gateways["content"], "reuse connections"
    assert_includes nat_gateways["content"], "Cloud Provider"
    assert_includes nat_gateways["content"], "hairpin NAT"
    assert_includes nat_gateways["content"], "PAT"
    assert_includes nat_gateways["content"], "split-horizon DNS"
    assert_includes nat_gateways["content"], "NodeLocal DNSCache"
    assert_includes firewall_netfilter["content"], "conntrack"
    assert_includes firewall_netfilter["content"], "iptables-save"
    assert_includes vpn_ipsec["content"], "IKEv2"
    assert_includes vpn_ipsec["content"], "traffic selectors"
    assert_includes vpn_ipsec["content"], "IKEv2 and Child SA Timeline"
    assert_includes vpn_ipsec["content"], "Proposal mismatch"
    assert_includes dhcp_routers_switches["content"], "DORA"
    assert_includes dhcp_routers_switches["content"], "DHCP relay"
    assert_includes dhcp_routers_switches["content"], "Option 82"
    assert_includes dhcp_routers_switches["content"], "DHCP snooping"
    assert_includes dhcp_routers_switches["content"], "Router Advertisements"
    assert_includes switching["content"], "/etc/hosts"
    assert_includes switching["content"], "DHCP snooping"
    assert_includes switching["content"], "802.1Q"
    assert_includes ip_addressing["content"], "CIDR"
    assert_includes icmp_mtu["content"], "Path MTU Discovery"
    assert_includes certificates["content"], "update-ca-certificates"
    assert_includes certificates["content"], "Chain Validation Checklist"
    assert_includes certificates["content"], "Certificate Management Examples"
    assert_includes certificates["content"], "openssl genpkey"
    assert_includes certificates["content"], "server-csr.cnf"
    assert_includes certificates["content"], "openssl verify"
    assert_includes certificates["content"], "certbot renew --dry-run"
    assert_includes certificates["content"], "ClusterIssuer"
    assert_includes certificates["content"], "cert-manager"
    assert_includes certificates["content"], "mTLS"
    assert_includes certificates["content"], "client certificate"
    assert_includes certificates["content"], "trust overlap"
    assert_includes certificates["content"], "Certificate Rotation Runbook"
    assert_includes certificates["content"], "mTLS client CA rotation"
    assert_includes tcp_sockets["content"], "TIME_WAIT"
    assert_includes tcp_sockets["content"], "Connection refused"
    assert_includes udp_quic["content"], "HTTP/3"
    assert_includes load_balancers["content"], "X-Forwarded-For"
    assert_includes load_balancers["content"], "Draining and Rolling Restarts"
    assert_includes load_balancers["content"], "Draining timeline"
    assert_includes load_balancers["content"], "Drain budget checklist"
    assert_includes resilience_timeouts["content"], "Timeout Budget"
    assert_includes resilience_timeouts["content"], "Timeout-Budget Calculator"
    assert_includes resilience_timeouts["content"], "backoff with jitter"
    assert_includes resilience_timeouts["content"], "Circuit breakers"
    assert_includes resilience_timeouts["content"], "load balancer draining"
    assert_includes resilience_timeouts["content"], "DNS TTLs"
    assert_includes forward_reverse_proxies["content"], "CONNECT"
    assert_includes forward_reverse_proxies["content"], "NO_PROXY"
    assert_includes http_proxy_debugging["content"], "curl --resolve"
    assert_includes http_proxy_debugging["content"], "HTTP CONNECT"
    assert_includes http_proxy_debugging["content"], "timeout alignment"
    assert_includes zero_trust_networking["content"], "nftables"
    assert_includes zero_trust_networking["content"], "mTLS"
    assert_includes zero_trust_networking["content"], "SNI"
    assert_includes zero_trust_networking["content"], "ALPN"
    assert_includes zero_trust_networking["content"], "auditd"
    assert_includes zero_trust_networking["content"], "SELinux"
    assert_includes zero_trust_networking["content"], "AppArmor"
    assert_includes zero_trust_networking["content"], "Zero-Trust Walkthrough"
    assert_includes zero_trust_networking["content"], "SPIFFE-like"
    assert_includes tcp_tls["content"], "SNI"
    assert_includes tcp_tls["content"], "Failure Ladder Example"
    assert_includes tcp_tls["content"], "Timeout Budget"
    assert_includes tcp_tls["content"], "Subject Alternative Name"
    assert_includes k8s_core["content"], "API Machinery"
    assert_includes k8s_core["content"], "admission"
    assert_includes k8s_core["content"], "CustomResourceDefinitions"
    assert_includes k8s_core["content"], "QoS"
    assert_includes k8s_troubleshooting["content"], "Pod Failure Workflow"
    assert_includes k8s_troubleshooting["content"], "Service and DNS Workflow"
    assert_includes k8s_troubleshooting["content"], "Evidence Capture"
    assert_includes k8s_troubleshooting["content"], "EndpointSlice"
    assert_includes k8s_troubleshooting["content"], "PVC pending"
    assert_includes k8s_dns["content"], "ndots"
    assert_includes k8s_dns["content"], "NATS"
    assert_includes k8s_dns["content"], "CoreDNS Failure Labs"
    assert_includes k8s_dns["content"], "EndpointSlice RBAC"
    assert_includes k8s_dns["content"], "SERVFAIL"
    assert_includes k8s_dns["content"], "TCP fallback"
    assert_includes k8s_nats_dns["content"], "headless Service"
    assert_includes k8s_nats_dns["content"], "StatefulSet Pod DNS"
    assert_includes k8s_nats_dns["content"], "cluster.advertise"
    assert_includes k8s_nats_dns["content"], "client_advertise"
    assert_includes k8s_nats_dns["content"], "NetworkPolicy"
    assert_includes k8s_nats_dns["content"], "certificate SAN"
    assert_includes k8s_nats_dns["content"], "publishNotReadyAddresses"
    assert_includes k8s_nats_dns["content"], "SRV records"
    assert_includes k8s_nats_dns["content"], "NodeLocal DNSCache"
    assert_includes k8s_nats_dns["content"], "gossiped server URLs"
    assert_includes k8s_external_dns["content"], "TXT registry"
    assert_includes k8s_external_dns["content"], "owner ID"
    assert_includes k8s_external_dns["content"], "external-dns.alpha.kubernetes.io/hostname"
    assert_includes k8s_services["content"], "EndpointSlices"
    assert_includes k8s_services["content"], "Service vs EndpointSlice"
    assert_includes k8s_pod_networking["content"], "CNI"
    assert_includes k8s_network_policy["content"], "default-deny"
    assert_includes k8s_network_policy["content"], "Lab Scenarios"
    assert_includes k8s_network_policy["content"], "namespaceSelector"
    assert_includes k8s_network_policy["content"], "Ingress plus egress isolation test"
    assert_includes k8s_ingress_gateway["content"], "Gateway API"
    assert_includes k8s_ingress_gateway["content"], "Ingress vs Gateway API"
    assert_includes identity["content"], "Identity Provider"
    assert_includes identity["content"], "authentication"
    assert_includes identity["content"], "authorization"
    assert_includes auth_protocols["content"], "SAML"
    assert_includes auth_protocols["content"], "OAuth 2.0"
    assert_includes auth_protocols["content"], "OpenID Connect"
    assert_includes auth_protocols["content"], "JWT"
    assert_includes auth_protocols["content"], "Authorization server"
    assert_includes auth_protocols["content"], "JWKS"
    assert_includes auth_protocols["content"], "IdP session cookie"
    assert_includes auth_protocols["content"], "Refresh token"
    assert_includes auth_protocols["content"], "Key Rotation and JWKS"
    assert_includes auth_protocols["content"], "PKCE"
    assert_includes auth_protocols["content"], "SAML Browser SSO Flow"
    assert_includes auth_protocols["content"], "OAuth/OIDC Authorization Code with PKCE"
    assert_includes auth_protocols["content"], "JWT Validation Decision Tree"
    assert_includes auth_protocols["content"], "Session and Token Lifetime Timeline"
    assert_includes domain_controllers["content"], "_msdcs"
    assert_includes domain_controllers["content"], "Kerberos"
    assert_includes domain_controllers["content"], "Global Catalog"
    assert_includes debian["content"], "Ubuntu Server"
    assert_includes istio["content"], "ambient mode"
    assert_includes istio["content"], "xDS"
    assert_includes istio["content"], "Listener"
    assert_includes service_mesh["content"], "ztunnel"
    assert_includes istio_traffic["content"], "VirtualService"
    assert_includes istio_traffic["content"], "xDS Route Debugging Path"
    assert_includes istio_security["content"], "PeerAuthentication"
    assert_includes istio_security["content"], "mTLS Handshake and Identity Path"
    assert_includes istio_security["content"], "Policy boundary matrix"
    assert_includes istio_gateways["content"], "TLS passthrough"
    assert_includes istio_zero_downtime["content"], "revision tags"
    assert_includes istio_zero_downtime["content"], "maxUnavailable: 0"
    assert_includes istio_zero_downtime["content"], "Gateway Upgrades"
    assert_includes istio_zero_downtime["content"], "ztunnel"
    assert_includes istio_observability["content"], "response flags"
    assert_includes istio_observability["content"], "Intent vs Runtime State"
    assert_includes istio_observability["content"], "xDS snapshots"
    assert_operator index.length, :>=, 70
  end

  def test_tag_index_and_knowledge_graph_render
    tags = read_site("tags/index.html")
    graph = read_site("knowledge-graph/index.html")

    assert_includes tags, 'id="kubernetes"'
    assert_includes tags, "Core Concepts"
    assert_includes tags, 'id="postgres"'
    assert_includes graph, 'class="graph-board"'
    assert_includes graph, 'class="graph-controls"'
    assert_includes graph, 'id="graph-filter"'
    assert_includes graph, 'data-graph-node'
    assert_includes graph, 'data-graph-cluster="kubernetes"'
    assert_includes graph, 'class="tag-cloud"'
    assert_includes graph, "Kubernetes"
    assert_includes graph, "Troubleshooting"
    assert_includes graph, "Incident Entry Points"
    refute_includes graph, 'data-graph-cluster="foundational-study-review"'
    refute_includes graph, 'data-graph-cluster="cross-topic-study-paths"'
    refute_includes graph, 'data-graph-cluster="scenario-labs"'
    refute_includes graph, 'data-graph-cluster="glossary"'
    refute_includes graph, 'data-graph-edge>Overview</a>'
    assert_includes graph, "DNS and CoreDNS"
    assert_includes graph, "NATS, DNS, and Kubernetes"
    assert_includes graph, "ExternalDNS"
    assert_includes graph, "Services and EndpointSlices"
    assert_includes graph, "Pod Networking and CNI"
    assert_includes graph, "NetworkPolicy"
    assert_includes graph, "Ingress, Gateway, and Load Balancers"
    assert_includes graph, "Identity and Access"
    assert_includes graph, "IdP, SAML, JWT, OAuth, and OIDC"
    assert_includes graph, "PostgreSQL"
    assert_includes graph, "PostgreSQL Operations and HA"
    assert_includes graph, "PgBouncer"
    assert_includes graph, "CloudNativePG"
    assert_includes graph, "OpenSearch"
    assert_includes graph, "Ceph"
    assert_includes graph, "Rook-Ceph"
    assert_includes graph, "Resolution and Caching"
    assert_includes graph, "Records, Responses, and Transport"
    assert_includes graph, "Domain Controllers"
    assert_includes graph, "Packet Path"
    assert_includes graph, "Request Path"
    assert_includes graph, "NAT Gateways and NAT"
    assert_includes graph, "Firewalls, iptables, and Netfilter"
    assert_includes graph, "VPNs and IPsec Tunnels"
    assert_includes graph, "Boot and Userspace"
    assert_includes graph, "Network Boot and Provisioning"
    assert_includes graph, "Kernel Modules and Devices"
    assert_includes graph, "Block Devices and Partitioning"
    assert_includes graph, "Mounts and fstab"
    assert_includes graph, "Mount Namespaces and Propagation"
    assert_includes graph, "ext4, XFS, and Repair"
    assert_includes graph, "Storage Drives, RAID, and DB Performance"
    assert_includes graph, "RAID, Multipath, and Device Mapper"
    assert_includes graph, "Storage Health and Performance"
    assert_includes graph, "Containerization, OCI, and VMs"
    assert_includes graph, "Backup and File Transfer"
    assert_includes graph, "Kernel Network Performance"
    assert_includes graph, "TCP Kernel Tuning"
    assert_includes graph, "Sockets and IPC"
    assert_includes graph, "Processes and Threads"
    assert_includes graph, "Certificates and HTTPS"
    assert_includes graph, "TCP and Sockets"
    assert_includes graph, "DHCP, Routers, and Switches"
    assert_includes graph, "Switching, VLANs, and Hosts"
    assert_includes graph, "IP Addressing and Subnetting"
    assert_includes graph, "ICMP, MTU, and Path Testing"
    assert_includes graph, "UDP, QUIC, and Connectionless Traffic"
    assert_includes graph, "Load Balancers and Proxies"
    assert_includes graph, "Forward and Reverse Proxies"
    assert_includes graph, "Debian and Ubuntu"
    assert_includes graph, "Users, Permissions, and sudo"
    assert_includes graph, "SSH Access"
    assert_includes graph, "Logs and Observability"
    assert_includes graph, "Scheduled Automation"
    assert_includes graph, "Time, Hostname, and Identity"
    assert_includes graph, "GPU Drivers"
    assert_includes graph, "systemd Networking"
    assert_includes graph, "systemd Socket Activation"
    assert_includes graph, "Istio"
    assert_includes graph, "Service Mesh"
    assert_includes graph, "Machine Learning"
    assert_includes graph, "Fine-Tuning and LoRA"
    assert_includes graph, "Retrieval-Augmented Generation"
    assert_includes graph, "Explainability"
  end

  def test_study_paths_and_labs_pages_render
    study_paths = read_site("docs/study-paths/index.html")
    labs = read_site("docs/labs/index.html")

    assert_includes study_paths, 'class="path-card"'
    assert_includes study_paths, 'data-path-card'
    assert_includes study_paths, 'data-path-progress-fill'
    assert_includes study_paths, 'data-path-step-url="/docs/ml/serving-inference-vllm/"'
    assert_includes study_paths, 'data-path-step-url="/docs/ml/inference-systems/"'
    assert_includes study_paths, 'data-path-step-url="/docs/ml/model-memory-math/"'
    assert_includes study_paths, 'data-path-step-url="/docs/ml/inference-benchmarking/"'
    assert_includes study_paths, 'data-path-step-url="/docs/ml/inference-runbooks/"'
    refute_includes study_paths, 'data-action="mark-complete"'
    refute_includes study_paths, 'data-page-complete-status'
    assert_includes study_paths, "Production ML from 101 to Advanced Systems"
    assert_includes study_paths, "PostgreSQL Reliability and Zero Downtime"

    assert_includes labs, 'class="lab-card"'
    assert_includes labs, 'data-lab-card="kubernetes-dns-outage"'
    assert_includes labs, 'data-lab-card="ceph-degraded-pgs"'
    assert_includes labs, 'data-lab-card="istio-mtls-policy-breakage"'
    assert_includes labs, 'data-lab-card="nat-exhaustion-api-errors"'
    assert_includes labs, 'data-lab-card="tls-cert-expiry-edge"'
    assert_includes labs, 'data-lab-card="opensearch-shard-pressure"'
    assert_includes labs, 'data-lab-card="rag-quality-regression"'
    refute_includes labs, 'class="lab-columns"'
    assert_includes labs, "Symptoms"
    assert_includes labs, "Evidence"
    assert_includes labs, "Command Examples"
    assert_includes labs, "Example output"
    assert_includes labs, "What it does:"
    assert_includes labs, 'class="lab-command-example"'
    refute_includes labs, 'class="lab-checks"'
    assert_includes labs, "Answer:"
    assert_includes labs, "vLLM Inference Latency Spike"
    assert_includes labs, "Ceph Degraded PGs After OSD Loss"
    assert_includes labs, "Istio mTLS Policy Breakage"
    assert_includes labs, "NAT Exhaustion and API Errors"
    assert_includes labs, "TLS Certificate Expiry at the Edge"
    assert_includes labs, "OpenSearch Shard Pressure"
    assert_includes labs, "RAG Quality Regression"

    embedded_lab = read_site("docs/ml/serving-inference-vllm/index.html")
    assert_includes embedded_lab, "Scenario Lab"
    assert_includes embedded_lab, "vLLM Inference Latency Spike"

    embedded_ceph_lab = read_site("docs/ceph/operations-recovery/index.html")
    assert_includes embedded_ceph_lab, "Scenario Lab"
    assert_includes embedded_ceph_lab, "Ceph Degraded PGs After OSD Loss"
  end

  def test_machine_learning_section_search_nav_and_content
    nav = YAML.load_file(File.join(ROOT, "_data/study_nav.yml"))
    ml_nav = nav.find { |item| item.fetch("title") == "Machine Learning" }
    refute_nil ml_nav

    expected_pages = {
      "Machine Learning" => ["docs/ml/index.html", ["ML 101 Foundations", "Math for ML", "Classical ML", "Transformer Internals", "LLM Inference Systems", "Model Memory Math", "Inference Benchmarking", "Inference Runbooks", "Advanced Inference and vLLM", "Responsible AI and Governance"]],
      "ML 101 Foundations" => ["docs/ml/ml-101-foundations/index.html", ["When Not To Use ML", "Overfitting", "Practical Lab"]],
      "Math for ML" => ["docs/ml/math-for-ml/index.html", ["Cosine Similarity", "Gradient Descent", "Attention Intuition"]],
      "Classical ML" => ["docs/ml/classical-ml/index.html", ["LogisticRegression", "Gradient boosting", "Tabular Workflow"]],
      "Deep Learning Fundamentals" => ["docs/ml/deep-learning-fundamentals/index.html", ["Training Stability", "Activation", "Practical Lab"]],
      "ML Models, Types, and Weights" => ["docs/ml/models-weights/index.html", ["Supervised", "Transformers", "tokenizer", "checkpoint"]],
      "Transformer Internals" => ["docs/ml/transformers-internals/index.html", ["RoPE", "KV Cache", "MoE Basics"]],
      "LLM Training Lifecycle" => ["docs/ml/llm-training-lifecycle/index.html", ["Continued pretraining", "RLHF", "DPO", "Synthetic Data"]],
      "ML Accelerators: GPU and TPU" => ["docs/ml/accelerators-gpu-tpu/index.html", ["GPU", "TPU", "BF16", "accelerator memory"]],
      "PyTorch Fundamentals" => ["docs/ml/pytorch-fundamentals/index.html", ["autograd", "nn.Module", "optimizer", "checkpoint"]],
      "Fine-Tuning and LoRA" => ["docs/ml/finetuning-lora/index.html", ["LoRA", "adapter", "fine-tuning", "regression eval", "Fine-tune release gate"]],
      "Advanced Fine-Tuning" => ["docs/ml/advanced-finetuning/index.html", ["QLoRA", "Multi-Adapter Serving", "Dataset Mixing"]],
      "Retrieval-Augmented Generation" => ["docs/ml/rag/index.html", ["embeddings", "chunking", "reranking", "faithfulness", "Retrieval debugging matrix"]],
      "Advanced RAG" => ["docs/ml/advanced-rag/index.html", ["GraphRAG", "Citation Verification", "Hybrid retrieval"]],
      "ML Agents and Tool Use" => ["docs/ml/agents/index.html", ["tool", "idempotency", "Guardrails", "trajectories", "Agent safety test cases"]],
      "Advanced Agents" => ["docs/ml/advanced-agents/index.html", ["Durable execution", "Trajectory Review", "Approval"]],
      "Multimodal ML" => ["docs/ml/multimodal-ml/index.html", ["OCR Pipeline", "Multimodal RAG", "Document QA Evidence"]],
      "ML Serving, Inference, and vLLM" => ["docs/ml/serving-inference-vllm/index.html", ["Plain Inference vs vLLM Inference", "Prefill vs Decode", "same LLM generation work", "KV-Cache Deep Dive", "bytes_per_value", "memory-bandwidth-sensitive", "application response caching", "PagedAttention Deep Dive", "block table", "Non-contiguous storage", "Copy-on-write", "prefill", "decode", "KV cache", "PagedAttention", "vLLM Tuning Matrix", "speculative decoding"]],
      "LLM Inference Systems" => ["docs/ml/inference-systems/index.html", ["Engine Choice Matrix", "TensorRT-LLM", "Hugging Face TGI", "llama.cpp", "SGLang", "Ollama", "API Contracts, Streaming, and Cancellation", "KV Cache Essentials", "PagedAttention Essentials", "Security and Tenant Isolation", "Performance Test Matrix", "Debugging Runbooks", "Quantization for Serving"]],
      "Model Memory Math" => ["docs/ml/model-memory-math/index.html", ["Weights vs KV Cache vs Activations", "Model artifact", "Weight Memory", "KV-Cache Examples", "Capacity Worksheet", "GQA", "INT4 weights still OOM"]],
      "Tokenizer and Chat Template Compatibility" => ["docs/ml/tokenizer-chat-template-compatibility/index.html", ["Compatibility Boundary", "Token ID diff", "special tokens", "stop sequence mismatch"]],
      "Inference Benchmarking" => ["docs/ml/inference-benchmarking/index.html", ["Benchmark Design", "TTFT p50", "ITL p50", "Benchmark Report", "Anti-Patterns"]],
      "Quantized Serving" => ["docs/ml/quantized-serving/index.html", ["AWQ", "GPTQ", "KV-cache quantization", "Quality Gates", "Rollout Flow"]],
      "Inference Engine Comparison" => ["docs/ml/inference-engine-comparison/index.html", ["Feature Matrix", "TensorRT-LLM", "llama.cpp", "SGLang", "Migration Plan"]],
      "vLLM Operations" => ["docs/ml/vllm-operations/index.html", ["Important Flags", "PagedAttention", "Prefix caching", "vLLM Runbook"]],
      "MoE Inference" => ["docs/ml/moe-inference/index.html", ["active parameters", "Expert parallelism", "all-to-all", "load imbalance"]],
      "Long-Context Serving" => ["docs/ml/long-context-serving/index.html", ["RoPE scaling", "Sliding-window attention", "lost-in-the-middle", "Long-Context Eval Design"]],
      "Inference Runbooks" => ["docs/ml/inference-runbooks/index.html", ["Symptom Split", "High TTFT", "Slow Inter-Token Latency", "Release Regression"]],
      "Advanced Inference and vLLM" => ["docs/ml/advanced-inference-vllm/index.html", ["Disaggregated prefill", "KV-Cache Memory Math", "speculative decoding"]],
      "ML Observability and Incident Response" => ["docs/ml/observability-incident-response/index.html", ["drift", "Prompt and retrieval logging", "Incident Runbook", "Quality Monitoring"]],
      "Advanced ML Observability" => ["docs/ml/advanced-observability/index.html", ["Trace Schema", "Online Evaluation", "Incident Review Template"]],
      "ML Data Pipelines and Feature Stores" => ["docs/ml/data-pipelines-feature-stores/index.html", ["feature store", "train/serve skew", "point-in-time correctness", "Data Quality Gates"]],
      "MLOps Systems" => ["docs/ml/mlops-systems/index.html", ["Model Registry Record", "Shadow evaluation", "Cost Governance"]],
      "ML Evaluation and CI/CD" => ["docs/ml/evaluation-ci-cd/index.html", ["golden set", "Regression gates", "Release Pipeline", "vLLM/runtime"]],
      "ML Evaluation Mastery" => ["docs/ml/evaluation-mastery/index.html", ["Statistical Confidence", "Contamination Controls", "Eval Case Schema"]],
      "ML Security and Privacy" => ["docs/ml/security-privacy/index.html", ["Prompt injection", "Data exfiltration", "Tenant isolation", "Security Release Gate"]],
      "ML Security Threats" => ["docs/ml/ml-security-threats/index.html", ["Membership inference", "Secure RAG Checklist", "Prompt Injection Test"]],
      "ML Prompt Operations" => ["docs/ml/prompt-operations/index.html", ["Prompt templates", "structured outputs", "Prompt Release Runbook", "generation config"]],
      "Advanced ML Architectures" => ["docs/ml/advanced-architectures/index.html", ["Mixture of Experts", "Long-Context Design", "Architecture Decision Record"]],
      "ML Performance Engineering" => ["docs/ml/performance-engineering/index.html", ["FlashAttention", "Activation checkpointing", "Performance Report"]],
      "ML Alignment and Evaluation" => ["docs/ml/alignment-evaluation/index.html", ["RLHF", "DPO", "red teaming", "regression eval"]],
      "ML Explainability" => ["docs/ml/explainability/index.html", ["SHAP", "LIME", "attention", "model card"]],
      "Responsible AI and Governance" => ["docs/ml/responsible-ai-governance/index.html", ["Dataset card", "Risk Classification", "Release Approval Checklist"]]
    }

    expected_pages.each do |_title, (relative_path, terms)|
      html = read_site(relative_path)
      text = text_content(html)
      assert_includes html, 'class="study-card-grid"', "Expected study cards in #{relative_path}"
      terms.each { |term| assert_includes text, term, "Expected #{term} in #{relative_path}" }
    end

    expected_urls = expected_pages.values.map { |relative_path, _terms| "/#{relative_path.sub(%r{/index\.html\z}, "/")}" }
    expected_urls.each do |url|
      assert ml_nav.fetch("children").any? { |item| item.fetch("url") == url }, "Expected ML nav to include #{url}"
    end

    index = JSON.parse(read_site("assets/js/search-index.json"))
    expected_pages.each do |title, (_relative_path, terms)|
      page = index.find { |item| item["title"] == title }
      refute_nil page, "Expected search index entry for #{title}"
      terms.each { |term| assert_includes page["content"], term, "Expected #{term} in search entry for #{title}" }
    end
  end

  def test_machine_learning_100_gap_closure_is_implemented
    index_text = text_content(read_site("docs/ml/index.html"))
    assert_includes index_text, "ML 100 Gap Closure Matrix"
    assert_includes index_text, "ML-GAP-001 through ML-GAP-012"
    assert_includes index_text, "ML-GAP-087 through ML-GAP-100"

    gap_pages = {
      "docs/ml/models-weights/index.html" => (1..12).to_a,
      "docs/ml/accelerators-gpu-tpu/index.html" => (13..23).to_a,
      "docs/ml/pytorch-fundamentals/index.html" => (24..35).to_a,
      "docs/ml/finetuning-lora/index.html" => (36..47).to_a,
      "docs/ml/rag/index.html" => (48..60).to_a,
      "docs/ml/agents/index.html" => (61..72).to_a,
      "docs/ml/alignment-evaluation/index.html" => (73..86).to_a,
      "docs/ml/explainability/index.html" => (87..100).to_a
    }

    observed = []
    gap_pages.each do |relative_path, expected_numbers|
      text = text_content(read_site(relative_path))
      page_numbers = text.scan(/ML-GAP-(\d{3})/).flatten.map(&:to_i).uniq.sort
      assert_equal expected_numbers, page_numbers, "Expected exact ML gap range in #{relative_path}"
      expected_numbers.each do |number|
        label = format("ML-GAP-%03d", number)
        assert_includes text, label, "Expected #{label} in #{relative_path}"
      end
      observed.concat(page_numbers)
    end

    assert_equal (1..100).to_a, observed.uniq.sort
  end

  def test_study_cards_render_and_script_supports_flipping
    html = read_site("docs/kubernetes/core-concepts/index.html")
    script = read_site("assets/js/study.js")

    assert_includes html, 'class="study-card-grid"'
    assert_includes html, 'class="study-card"'
    assert_includes html, "What is the smallest deployable unit in Kubernetes?"
    assert_includes html, "A Pod."
    assert_includes script, 'document.querySelectorAll(".study-card")'
    assert_includes script, 'card.classList.toggle("flipped")'
  end

  def test_major_study_guides_have_study_cards
    [
      "docs/linux/index.html",
      "docs/linux/lvm/index.html",
      "docs/linux/systemd/index.html",
      "docs/linux/resolv-conf/index.html",
      "docs/linux/boot-userspace/index.html",
      "docs/linux/network-boot-automated-provisioning/index.html",
      "docs/linux/kernel-modules-devices/index.html",
      "docs/linux/filesystems-io/index.html",
      "docs/linux/block-devices-partitions/index.html",
      "docs/linux/mounts-fstab/index.html",
      "docs/linux/mount-namespaces-propagation/index.html",
      "docs/linux/ext4-xfs-repair/index.html",
      "docs/linux/storage-drives-raid-database-performance/index.html",
      "docs/linux/raid-multipath-device-mapper/index.html",
      "docs/linux/storage-health-performance/index.html",
      "docs/linux/containerization-oci-vms/index.html",
      "docs/linux/network-stack/index.html",
      "docs/linux/kernel-network-performance/index.html",
      "docs/linux/tcp-kernel-tuning/index.html",
      "docs/linux/ebpf-tracing/index.html",
      "docs/linux/memory-pressure-oom/index.html",
      "docs/linux/syscall-debugging/index.html",
      "docs/linux/security-controls/index.html",
      "docs/linux/package-boot-recovery/index.html",
      "docs/linux/performance-triage-runbooks/index.html",
      "docs/linux/sockets-ipc/index.html",
      "docs/linux/processes-threads/index.html",
      "docs/linux/debian-ubuntu/index.html",
      "docs/linux/users-permissions-sudo/index.html",
      "docs/linux/ssh-access/index.html",
      "docs/linux/logs-observability/index.html",
      "docs/linux/scheduled-automation/index.html",
      "docs/linux/backup-transfer-rsync-scp-snapshots/index.html",
      "docs/linux/time-hostname/index.html",
      "docs/linux/gpu-drivers/index.html",
      "docs/linux/systemd-networking/index.html",
      "docs/linux/systemd-socket-network-services/index.html",
      "docs/foundational-study-review/index.html",
      "docs/linux/practical-examples/index.html",
      "docs/dns/practical-examples/index.html",
      "docs/networking/practical-examples/index.html",
      "docs/kubernetes/practical-examples/index.html",
      "docs/identity/practical-examples/index.html",
      "docs/databases/practical-examples/index.html",
      "docs/ceph/practical-examples/index.html",
      "docs/istio/practical-examples/index.html",
      "docs/troubleshooting/practical-examples/index.html",
      "docs/troubleshooting/index.html",
      "docs/kubernetes/index.html",
      "docs/kubernetes/core-concepts/index.html",
      "docs/kubernetes/troubleshooting/index.html",
      "docs/kubernetes/networking/index.html",
      "docs/kubernetes/dns-coredns/index.html",
      "docs/kubernetes/nats-dns-kubernetes/index.html",
      "docs/kubernetes/external-dns/index.html",
      "docs/kubernetes/services-endpointslices/index.html",
      "docs/kubernetes/pod-networking-cni/index.html",
      "docs/kubernetes/network-policy/index.html",
      "docs/kubernetes/ingress-gateway-load-balancers/index.html",
      "docs/kubernetes/storage-upgrades/index.html",
      "docs/identity/index.html",
      "docs/identity/auth-protocols/index.html",
      "docs/dns/index.html",
      "docs/dns/resolution-caching/index.html",
      "docs/dns/authoritative-zones/index.html",
      "docs/dns/dnssec-privacy/index.html",
      "docs/dns/records-transport-operations/index.html",
      "docs/dns/domain-controllers/index.html",
      "docs/networking/index.html",
      "docs/networking/packet-path/index.html",
      "docs/networking/packet-capture-analysis/index.html",
      "docs/networking/routing-nat-firewalls/index.html",
      "docs/networking/bgp-dynamic-routing/index.html",
      "docs/networking/cloud-networking/index.html",
      "docs/networking/network-namespaces-virtual-networking/index.html",
      "docs/networking/ipv6-operations/index.html",
      "docs/networking/nat-gateways/index.html",
      "docs/networking/firewalls-iptables-netfilter/index.html",
      "docs/networking/vpn-ipsec-tunnels/index.html",
      "docs/networking/dhcp-routers-switches/index.html",
      "docs/networking/switching-vlans-hosts/index.html",
      "docs/networking/ip-addressing-subnetting/index.html",
      "docs/networking/icmp-mtu-path-testing/index.html",
      "docs/networking/certificates-https/index.html",
      "docs/networking/tcp-sockets/index.html",
      "docs/networking/udp-quic-connectionless/index.html",
      "docs/networking/load-balancers-proxies/index.html",
      "docs/networking/proxies-forward-reverse/index.html",
      "docs/networking/http-proxy-debugging/index.html",
      "docs/networking/tcp-tls-http/index.html",
      "docs/istio/index.html",
      "docs/istio/service-mesh/index.html",
      "docs/ceph/index.html",
      "docs/ceph/rook-ceph/index.html",
      "docs/databases/index.html",
      "docs/databases/postgres/index.html",
      "docs/databases/postgres/operations-ha/index.html",
      "docs/databases/postgres/zero-downtime-upgrades/index.html",
      "docs/databases/postgres/pgbouncer/index.html",
      "docs/databases/postgres/cloudnativepg/index.html",
      "docs/databases/opensearch/index.html",
      "docs/ml/index.html",
      "docs/ml/ml-101-foundations/index.html",
      "docs/ml/math-for-ml/index.html",
      "docs/ml/classical-ml/index.html",
      "docs/ml/deep-learning-fundamentals/index.html",
      "docs/ml/models-weights/index.html",
      "docs/ml/transformers-internals/index.html",
      "docs/ml/llm-training-lifecycle/index.html",
      "docs/ml/accelerators-gpu-tpu/index.html",
      "docs/ml/pytorch-fundamentals/index.html",
      "docs/ml/finetuning-lora/index.html",
      "docs/ml/advanced-finetuning/index.html",
      "docs/ml/rag/index.html",
      "docs/ml/advanced-rag/index.html",
      "docs/ml/agents/index.html",
      "docs/ml/advanced-agents/index.html",
      "docs/ml/multimodal-ml/index.html",
      "docs/ml/serving-inference-vllm/index.html",
      "docs/ml/inference-systems/index.html",
      "docs/ml/model-memory-math/index.html",
      "docs/ml/tokenizer-chat-template-compatibility/index.html",
      "docs/ml/inference-benchmarking/index.html",
      "docs/ml/quantized-serving/index.html",
      "docs/ml/inference-engine-comparison/index.html",
      "docs/ml/vllm-operations/index.html",
      "docs/ml/moe-inference/index.html",
      "docs/ml/long-context-serving/index.html",
      "docs/ml/inference-runbooks/index.html",
      "docs/ml/advanced-inference-vllm/index.html",
      "docs/ml/observability-incident-response/index.html",
      "docs/ml/advanced-observability/index.html",
      "docs/ml/data-pipelines-feature-stores/index.html",
      "docs/ml/mlops-systems/index.html",
      "docs/ml/evaluation-ci-cd/index.html",
      "docs/ml/evaluation-mastery/index.html",
      "docs/ml/security-privacy/index.html",
      "docs/ml/ml-security-threats/index.html",
      "docs/ml/prompt-operations/index.html",
      "docs/ml/advanced-architectures/index.html",
      "docs/ml/performance-engineering/index.html",
      "docs/ml/alignment-evaluation/index.html",
      "docs/ml/explainability/index.html",
      "docs/ml/responsible-ai-governance/index.html"
    ].each do |relative_path|
      html = read_site(relative_path)

      assert_includes html, 'class="study-card-grid"', "Expected study cards in #{relative_path}"
      assert_operator html.scan('class="study-card"').length, :>=, 3, "Expected multiple cards in #{relative_path}"
    end
  end

  def test_all_content_docs_render_study_cards
    markdown_paths = Dir[File.join(ROOT, "docs/**/*.md")]

    markdown_paths.each do |path|
      relative_markdown = path.delete_prefix("#{ROOT}/")
      relative_html =
        if File.basename(relative_markdown) == "index.md"
          relative_markdown.sub(%r{index\.md\z}, "index.html")
        else
          relative_markdown.sub(/\.md\z/, "/index.html")
        end
      html = read_site(relative_html)

      assert_includes html, 'class="study-card-grid"', "Expected study-card grid in #{relative_html}"
      assert_operator html.scan('class="study-card"').length, :>=, 3, "Expected at least three rendered study cards in #{relative_html}"
    end
  end

  def test_study_deck_cards_are_well_formed_unique_and_substantial
    decks = YAML.load_file(File.join(ROOT, "_data/study_decks.yml"))
    total_cards = 0

    decks.each do |deck_name, deck|
      cards = deck.fetch("cards")
      questions = cards.map { |card| card.fetch("q") }
      total_cards += cards.length

      assert_operator cards.length, :>=, 25, "Expected #{deck_name} deck to be substantial"
      assert_equal questions.uniq.length, questions.length, "Expected unique questions inside #{deck_name} deck"

      cards.each do |card|
        question = card.fetch("q")
        answer = card.fetch("a")

        assert_match(/\?\z/, question, "Expected question to end with ? in #{deck_name}: #{question}")
        assert_operator question.length, :<, 140, "Question is too long in #{deck_name}: #{question}"
        assert_operator answer.length, :<, 260, "Answer is too long in #{deck_name}: #{answer}"
        refute_empty answer.strip, "Expected non-empty answer in #{deck_name}: #{question}"
      end
    end

    assert_operator total_cards, :>=, 500
  end

  def test_inline_study_cards_are_well_formed_and_unique_per_page
    total_cards = 0

    Dir[File.join(ROOT, "docs/**/*.md")].each do |path|
      text = File.read(path)
      cards = text.scan(/study-card\.html question="([^"]+)" answer="([^"]+)"/)
      questions = cards.map(&:first)
      total_cards += cards.length

      assert_equal questions.uniq.length, questions.length, "Expected unique inline study-card questions in #{path}"

      cards.each do |question, answer|
        assert_match(/\?\z/, question, "Expected inline card question to end with ?: #{path}: #{question}")
        assert_operator question.length, :<, 160, "Inline question is too long in #{path}: #{question}"
        assert_operator answer.length, :<, 280, "Inline answer is too long in #{path}: #{answer}"
        refute_empty answer.strip, "Expected non-empty inline answer in #{path}: #{question}"
      end
    end

    assert_operator total_cards, :>=, 300
  end

  def test_certificate_management_examples_render
    html = read_site("docs/networking/certificates-https/index.html")
    text = text_content(html)

    [
      "Certificate Management Examples",
      "server-csr.cnf",
      "subjectAltName",
      "openssl genpkey",
      "openssl verify -CAfile lab-root-ca.crt",
      "openssl x509 -in served-chain.pem -checkend 1209600 -noout",
      "sudo update-ca-certificates --fresh",
      "sudo certbot renew --dry-run",
      "ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem",
      "kind: ClusterIssuer",
      "kind: Certificate",
      "kubectl -n apps describe certificate app-example-com"
    ].each do |term|
      assert_includes text, term
    end

    assert_operator html.scan('class="language-bash').length, :>=, 8
    assert_includes html, 'class="language-yaml highlighter-rouge"'
  end

  def test_embedded_practical_examples_cover_each_major_area_with_code
    pages = {
      "docs/linux/systemd-networking/index.html" => ["VLAN and Bridge Example", "networkctl status", "systemd-networkd"],
      "docs/linux/containerization-oci-vms/index.html" => ["Kubernetes Resource Mapping", "memory.high", "cpu.stat"],
      "docs/dns/resolution-caching/index.html" => ["Intermittent DNS Runbook", "dig +tcp", "tcpdump"],
      "docs/networking/cross-layer-incident-runbooks/index.html" => ["HTTP 504", "Connection Refused", "Node Can Reach Service but Pod Cannot"],
      "docs/networking/packet-path/index.html" => ["Production Packet-Capture Labs", "MTU black hole", "QUIC blocked"],
      "docs/networking/firewalls-iptables-netfilter/index.html" => ["Host Firewall Example", "nftables", "ct state established"],
      "docs/kubernetes/networking/index.html" => ["Service Datapath Modes", "allow-dns-egress", "Pod-to-External Egress"],
      "docs/kubernetes/pod-networking-cni/index.html" => ["Pod Packet Paths", "Hairpin and SNAT Checks", "kubectl exec"],
      "docs/identity/practical-examples/index.html" => ["Identity OAuth and JWT Examples", "OAuth authorization-code token exchange", "jwks.json"],
      "docs/databases/practical-examples/index.html" => ["PostgreSQL Examples", "CREATE INDEX CONCURRENTLY", "PgBouncer Example", "OpenSearch Examples"],
      "docs/ceph/practical-examples/index.html" => ["Ceph Examples", "ceph osd pool create", "rbd create"],
      "docs/istio/practical-examples/index.html" => ["Istio Examples", "kind: VirtualService", "AuthorizationPolicy"],
      "docs/troubleshooting/practical-examples/index.html" => ["Troubleshooting Capture Example", "journalctl -p warning..alert"]
    }

    total_code_blocks = 0
    pages.each do |relative_path, expected_terms|
      html = read_site(relative_path)
      text = text_content(html)
      expected_terms.each { |term| assert_includes text, term }
      assert_includes html, 'class="study-card-grid"'
      total_code_blocks += html.scan('class="language-').length
    end

    assert_operator total_code_blocks, :>=, 20
  end

  def test_operational_pages_have_embedded_examples_and_invariants
    operational_pages = [
      "docs/networking/request-path/index.html",
      "docs/troubleshooting/incident-entrypoints/index.html",
      "docs/networking/cross-layer-incident-runbooks/index.html",
      "docs/networking/packet-path/index.html",
      "docs/networking/packet-capture-analysis/index.html",
      "docs/networking/nat-gateways/index.html",
      "docs/networking/cloud-networking/index.html",
      "docs/networking/datacenter-l2-l3-operations/index.html",
      "docs/networking/resilience-timeouts-draining/index.html",
      "docs/networking/zero-trust-networking/index.html",
      "docs/networking/certificates-https/index.html",
      "docs/kubernetes/networking/index.html",
      "docs/kubernetes/dns-coredns/index.html",
      "docs/kubernetes/network-policy/index.html",
      "docs/kubernetes/pod-networking-cni/index.html",
      "docs/kubernetes/services-endpointslices/index.html",
      "docs/linux/containerization-oci-vms/index.html",
      "docs/linux/memory-pressure-oom/index.html",
      "docs/linux/kernel-network-performance/index.html",
      "docs/linux/systemd-networking/index.html"
    ]

    operational_pages.each do |relative_path|
      html = read_site(relative_path)
      text = text_content(html)

      assert_includes text, "Command Examples", "Expected command examples in #{relative_path}"
      assert_includes text, "Example output", "Expected example output in #{relative_path}"
      assert_includes text, "What it does", "Expected command purpose text in #{relative_path}"
      assert_includes html, 'class="study-card-grid"', "Expected study cards in #{relative_path}"
      assert_includes text, "References", "Expected references in #{relative_path}"
      assert_operator html.scan('class="language-').length, :>=, 1, "Expected at least one practical code example in #{relative_path}"
      assert_match(/Runbook|Flow|Lab|Checklist|Matrix|Diagram|Gallery|Example|Troubleshooting/, text, "Expected operational workflow content in #{relative_path}")
    end
  end

  def test_content_pages_have_required_front_matter_and_references
    markdown_paths = (Dir[File.join(ROOT, "docs/**/*.md")] + Dir[File.join(ROOT, "docs/*.md")]).uniq

    markdown_paths.each do |path|
      relative_path = path.delete_prefix("#{ROOT}/")
      text = File.read(path)
      front_matter = text[%r{\A---\n(.*?)\n---}m, 1]

      refute_nil front_matter, "Expected front matter in #{relative_path}"
      %w[title layout permalink summary tags].each do |key|
        assert_match(/^#{Regexp.escape(key)}:/, front_matter, "Expected #{key} in #{relative_path}")
      end

      assert_includes text, "## References", "Expected references in #{relative_path}"
    end
  end

  def test_operational_pages_have_runbook_callouts_and_diagrams
    {
      "docs/networking/request-path/index.html" => ["sequenceDiagram", "End-to-End Diagram", "Response Path"],
      "docs/kubernetes/networking/index.html" => ["flowchart LR", "Service Datapath Diagrams", "eBPF replacement mode"],
      "docs/kubernetes/dns-coredns/index.html" => ["flowchart LR", "DNS Resolution Diagram", "CoreDNS Failure Labs"],
      "docs/linux/containerization-oci-vms/index.html" => ["flowchart TB", "cgroup v2 Labs", "memory.events"],
      "docs/networking/resilience-timeouts-draining/index.html" => ["flowchart LR", "Timeout-Budget Calculator", "Load Balancer Draining"],
      "docs/kubernetes/storage-upgrades/index.html" => ["version-callout", "runbook-panel", "flowchart LR", "Post-Upgrade Validation"],
      "docs/databases/postgres/cloudnativepg/index.html" => ["version-callout", "runbook-panel", "flowchart LR", "Operator Upgrades"],
      "docs/databases/postgres/operations-ha/index.html" => ["flowchart LR", "Detect primary failure", "Validate writes, WAL archive, backups"],
      "docs/databases/postgres/zero-downtime-upgrades/index.html" => ["version-callout", "runbook-panel", "flowchart LR", "Blue/Green Logical Replication Runbook"],
      "docs/ceph/operations-recovery/index.html" => ["runbook-panel", "flowchart LR", "Recovery and Backfill"],
      "docs/istio/observability-troubleshooting/index.html" => ["flowchart LR", "xDS snapshots", "Intent vs Runtime State"],
      "docs/linux/storage-drives-raid-database-performance/index.html" => ["flowchart TB", "RAID vs LVM vs Filesystem", "Physical disks / cloud volumes"],
      "docs/ml/model-memory-math/index.html" => ["flowchart LR", "Weights vs KV Cache vs Activations", "Model artifact"],
      "docs/istio/zero-downtime-upgrades/index.html" => ["runbook-panel", "flowchart LR", "Gateway Upgrades"]
    }.each do |relative_path, expected_terms|
      html = read_site(relative_path)
      expected_terms.each { |term| assert_includes html, term, "Expected #{term} in #{relative_path}" }
    end
  end

  def test_internal_links_resolve_to_rendered_files
    html_paths = Dir[File.join(ROOT, "_site/**/*.html")].reject do |path|
      path.include?("/_site/playwright-report/")
    end

    html_paths.each do |path|
      html = File.read(path)
      current_dir = File.dirname(path)
      html.scan(/href="([^"]+)"/).flatten.each do |href|
        next if href.start_with?("#", "http://", "https://", "mailto:", "javascript:")
        next if href.start_with?("tel:")

        href_path = href.split("#", 2).first
        next if href_path.empty?

        target =
          if href_path.start_with?("/")
            File.join(ROOT, "_site", href_path.delete_prefix("/"))
          else
            File.expand_path(href_path, current_dir)
          end

        target = File.join(target, "index.html") if href_path.end_with?("/")
        target = File.join(target, "index.html") if File.directory?(target)

        assert_path_exists target, "Broken internal link #{href.inspect} from #{path.delete_prefix("#{ROOT}/")}"
      end
    end
  end

  def test_overarching_topics_use_launcher_instead_of_rendering_50_cards_inline
    {
      "linux" => "docs/linux/index.html",
      "kubernetes" => "docs/kubernetes/index.html",
      "dns" => "docs/dns/index.html",
      "networking" => "docs/networking/index.html",
      "postgres" => "docs/databases/postgres/index.html",
      "ceph" => "docs/ceph/index.html",
      "istio" => "docs/istio/index.html",
      "ml" => "docs/ml/index.html"
    }.each do |deck, relative_path|
      html = read_site(relative_path)

      assert_includes html, 'class="study-deck-launcher"'
      assert_includes html, "data-deck=\"#{deck}\""
      assert_includes html, 'data-action="open-study"'
      assert_operator html.scan('class="study-card"').length, :<, 50, "Expected #{deck} deck to stay out of the document scroll"
    end
  end

  def test_study_deck_data_has_at_least_50_cards_per_overarching_topic
    decks = YAML.load_file(File.join(ROOT, "_data/study_decks.yml"))

    %w[linux kubernetes dns networking postgres ceph istio ml].each do |deck|
      assert_operator decks.fetch(deck).fetch("cards").length, :>=, 50, "Expected at least 50 cards in #{deck} deck"
    end
  end

  def test_generated_study_deck_json_exposes_all_decks
    decks = JSON.parse(read_site("assets/js/study-decks.json"))

    %w[linux kubernetes dns networking postgres ceph istio ml].each do |deck|
      assert_operator decks.fetch(deck).fetch("cards").length, :>=, 50
      assert decks.fetch(deck).fetch("cards").first.key?("q")
      assert decks.fetch(deck).fetch("cards").first.key?("a")
    end
  end

  def test_study_mode_supports_global_specific_review_test_and_reset
    html = read_site("index.html")
    script = read_site("assets/js/study.js")
    css = read_site("assets/css/study.css")

    assert_includes html, 'id="study-modal"'
    assert_includes html, 'class="study-workspace"'
    assert_includes html, 'class="study-setup study-filters"'
    assert_includes html, 'id="study-summary"'
    assert_includes html, 'data-study-summary="selected"'
    assert_includes html, 'id="study-last-missed"'
    assert_includes html, 'id="study-due-counts"'
    assert_includes html, 'class="study-topic-panel"'
    assert_includes html, 'class="study-option-panel"'
    assert_includes html, 'id="study-all-topics"'
    assert_includes html, 'id="study-topic-list"'
    assert_includes html, 'class="study-mode-toggle"'
    assert_includes html, 'name="study-mode" value="review" checked'
    assert_includes html, 'name="study-mode" value="test"'
    assert_includes html, 'id="study-size-select"'
    assert_includes html, '<option value="all">All selected</option>'
    assert_includes html, '<option value="10">10 cards</option>'
    refute_includes html, 'data-action="previous-card"'
    refute_includes html, 'data-action="next-card"'
    refute_includes html, 'data-action="reveal-card"'
    assert_includes html, 'data-action="mark-right"'
    assert_includes html, 'data-action="mark-wrong"'
    assert_includes html, 'data-action="reset-study"'
    assert_includes html, 'id="study-progress-fill"'
    assert_includes html, 'id="study-stage-card" role="button" tabindex="0" aria-pressed="false" aria-keyshortcuts="Enter Space ArrowLeft ArrowRight ArrowUp ArrowDown"'
    assert_includes html, 'id="study-card-state"'
    assert_includes html, 'id="study-card-label">Ready</span>'
    assert_includes html, 'id="study-card-text">Click card to start</p>'
    assert_includes html, 'id="study-card-hint">Click this card to begin.</small>'
    assert_includes html, 'id="study-keyboard-hints"'
    assert_includes html, 'id="study-bury-card"'

    assert_includes script, "study-decks.json"
    assert_includes script, "studyFilters"
    assert_includes script, "studyLastMissed"
    assert_includes script, "openStudy"
    assert_includes script, "studyProgressFill"
    assert_includes script, "selectedStudyDecks"
    assert_includes script, "selectedStudyMode"
    assert_includes script, "saveStudyFilters"
    assert_includes script, "applySavedStudyFilters"
    assert_includes script, "updateStudySummary"
    assert_includes script, "moveStudyCard"
    assert_includes script, "startOrRevealStudyCard"
    assert_includes script, 'studyStageCard.addEventListener("click"'
    assert_includes script, "revealStudyCard();"
    assert_includes script, 'studyStageCard.setAttribute("aria-pressed"'
    assert_includes script, 'event.key === "ArrowLeft"'
    assert_includes script, 'event.key === "ArrowRight"'
    assert_includes script, 'event.key === "ArrowUp" || event.key === "ArrowDown"'
    assert_includes script, "Click to reveal the answer."
    assert_includes script, "buryCurrentCard"
    assert_includes script, "touchstart"
    assert_includes script, "touchend"
    assert_includes script, "markStudyCard"
    assert_includes script, "Complete:"
    assert_includes script, "is-advancing"

    assert_includes css, ".study-card-grid"
    assert_includes css, "display: none"
    assert_includes css, ".study-modal"
    assert_includes css, ".study-workspace"
    assert_includes css, ".study-filters"
    assert_includes css, ".study-summary-panel"
    assert_includes css, ".study-due-counts"
    assert_includes css, ".study-topic-meter"
    assert_includes css, ".study-mode-toggle"
    assert_includes css, ".study-topic-chip"
    assert_includes css, ".study-progress-track"
    assert_includes css, ".study-stage-card"
    assert_includes css, ".study-stage-card small"
    assert_includes css, ".study-keyboard-hints"
    assert_includes css, ".study-bury-button"
  end

  def test_researched_topic_coverage_is_present
    corpus = [
      "docs/linux/index.html",
      "docs/linux/lvm/index.html",
      "docs/linux/systemd/index.html",
      "docs/linux/resolv-conf/index.html",
      "docs/linux/boot-userspace/index.html",
      "docs/linux/network-boot-automated-provisioning/index.html",
      "docs/linux/kernel-modules-devices/index.html",
      "docs/linux/filesystems-io/index.html",
      "docs/linux/block-devices-partitions/index.html",
      "docs/linux/mounts-fstab/index.html",
      "docs/linux/mount-namespaces-propagation/index.html",
      "docs/linux/ext4-xfs-repair/index.html",
      "docs/linux/storage-drives-raid-database-performance/index.html",
      "docs/linux/raid-multipath-device-mapper/index.html",
      "docs/linux/storage-health-performance/index.html",
      "docs/linux/containerization-oci-vms/index.html",
      "docs/linux/network-stack/index.html",
      "docs/linux/kernel-network-performance/index.html",
      "docs/linux/tcp-kernel-tuning/index.html",
      "docs/linux/sockets-ipc/index.html",
      "docs/linux/processes-threads/index.html",
      "docs/linux/debian-ubuntu/index.html",
      "docs/linux/users-permissions-sudo/index.html",
      "docs/linux/ssh-access/index.html",
      "docs/linux/logs-observability/index.html",
      "docs/linux/scheduled-automation/index.html",
      "docs/linux/backup-transfer-rsync-scp-snapshots/index.html",
      "docs/linux/time-hostname/index.html",
      "docs/linux/gpu-drivers/index.html",
      "docs/linux/systemd-networking/index.html",
      "docs/linux/systemd-socket-network-services/index.html",
      "docs/troubleshooting/index.html",
      "docs/kubernetes/index.html",
      "docs/kubernetes/core-concepts/index.html",
      "docs/kubernetes/networking/index.html",
      "docs/kubernetes/dns-coredns/index.html",
      "docs/kubernetes/nats-dns-kubernetes/index.html",
      "docs/kubernetes/external-dns/index.html",
      "docs/kubernetes/services-endpointslices/index.html",
      "docs/kubernetes/pod-networking-cni/index.html",
      "docs/kubernetes/network-policy/index.html",
      "docs/kubernetes/ingress-gateway-load-balancers/index.html",
      "docs/kubernetes/storage-upgrades/index.html",
      "docs/identity/index.html",
      "docs/identity/auth-protocols/index.html",
      "docs/dns/index.html",
      "docs/dns/resolution-caching/index.html",
      "docs/dns/authoritative-zones/index.html",
      "docs/dns/dnssec-privacy/index.html",
      "docs/dns/records-transport-operations/index.html",
      "docs/dns/domain-controllers/index.html",
      "docs/networking/index.html",
      "docs/networking/packet-path/index.html",
      "docs/networking/routing-nat-firewalls/index.html",
      "docs/networking/nat-gateways/index.html",
      "docs/networking/firewalls-iptables-netfilter/index.html",
      "docs/networking/vpn-ipsec-tunnels/index.html",
      "docs/networking/dhcp-routers-switches/index.html",
      "docs/networking/switching-vlans-hosts/index.html",
      "docs/networking/ip-addressing-subnetting/index.html",
      "docs/networking/icmp-mtu-path-testing/index.html",
      "docs/networking/certificates-https/index.html",
      "docs/networking/tcp-sockets/index.html",
      "docs/networking/udp-quic-connectionless/index.html",
      "docs/networking/load-balancers-proxies/index.html",
      "docs/networking/proxies-forward-reverse/index.html",
      "docs/networking/tcp-tls-http/index.html",
      "docs/istio/index.html",
      "docs/istio/service-mesh/index.html",
      "docs/ceph/index.html",
      "docs/ceph/rook-ceph/index.html",
      "docs/databases/postgres/index.html",
      "docs/databases/postgres/operations-ha/index.html",
      "docs/databases/postgres/zero-downtime-upgrades/index.html",
      "docs/databases/postgres/pgbouncer/index.html",
      "docs/databases/postgres/cloudnativepg/index.html",
      "docs/databases/opensearch/index.html"
    ].map { |path| text_content(read_site(path)) }.join("\n")

    [
      "Physical Volume",
      "Volume Group",
      "Logical Volume",
      "thin pool",
      "snapshot",
      "pvmove",
      "vgcfgbackup",
      "systemd",
      "unit",
      "target",
      "journalctl",
      "drop-in",
      "timer",
      "resolv.conf",
      "ndots",
      "search",
      "nameserver",
      "systemd-resolved",
      "initramfs",
      "PID 1",
      "kernel command line",
      "bootloader",
      "UEFI",
      "EFI System Partition",
      "systemd-boot",
      "Unified Kernel Image",
      "PXE",
      "iPXE",
      "TFTP",
      "ProxyDHCP",
      "UEFI HTTP Boot",
      "Ubuntu autoinstall",
      "cloud-init NoCloud",
      "Kickstart",
      "preseed",
      "NoCloud-Net",
      "BMC",
      "one-time boot",
      "rootwait",
      "rootdelay",
      "modprobe",
      "modprobe.d",
      "modalias",
      "devtmpfs",
      "sysfs",
      "DKMS",
      "VFS",
      "inode",
      "page cache",
      "fsync",
      "/dev/disk/by-id",
      "PARTUUID",
      "major and minor",
      "GPT",
      "UUID",
      "udev",
      "findmnt --verify",
      "/etc/fstab",
      "systemd mount",
      "systemd-fstab-generator",
      "x-systemd.device-timeout",
      "x-systemd.automount",
      "mount namespace",
      "mountinfo",
      "bind mount",
      "propagation",
      "nsenter",
      "chroot",
      "pivot_root",
      "overlay",
      "tmpfs",
      "ext4",
      "XFS",
      "xfs_repair",
      "e2fsck",
      "fstrim",
      "SSD",
      "HDD",
      "RAID 0",
      "RAID 1",
      "RAID 5",
      "RAID 6",
      "RAID 10",
      "RAID 0+1",
      "striping",
      "mirroring",
      "parity",
      "write penalty",
      "read-modify-write",
      "stripe width",
      "Write-intent bitmap",
      "Disk Failure Recovery",
      "RAID Failure Modes",
      "degraded array",
      "rebuild",
      "LVM With RAID",
      "lvmraid",
      "lv_health_status",
      "PostgreSQL Storage Mapping",
      "PostgreSQL examples",
      "Elasticsearch Storage Mapping",
      "Elasticsearch examples",
      "random_page_cost",
      "effective_io_concurrency",
      "shard replicas",
      "md RAID",
      "mdadm",
      "device mapper",
      "dm-crypt",
      "LUKS",
      "multipath",
      "WWID",
      "SMART",
      "NVMe health",
      "iostat",
      "I/O errors",
      "Unix domain sockets",
      "AF_UNIX",
      "sockstat",
      "listen queues",
      "pipes",
      "shared memory",
      "TID",
      "thread group",
      "PID namespace",
      "SIGTERM",
      "SIGKILL",
      "top -H",
      "network namespace",
      "veth pair",
      "OCI",
      "Open Container Initiative",
      "Runtime Specification",
      "Image Specification",
      "Distribution Specification",
      "containerd",
      "runc",
      "seccomp",
      "capabilities",
      "user namespace",
      "cgroups",
      "cgroup v2",
      "cpu.max",
      "memory.max",
      "pids.max",
      "overlayfs",
      "lowerdir",
      "upperdir",
      "copy-up",
      "whiteout",
      "Linux bridge",
      "docker0",
      "macvlan",
      "ipvlan",
      "VXLAN",
      "KVM",
      "hypervisor",
      "Hyper-V isolation",
      "WSL 2",
      "Virtual Machine",
      "netfilter",
      "conntrack",
      "qdisc",
      "NAT gateway",
      "SNAT",
      "DNAT",
      "PAT",
      "NAPT",
      "MASQUERADE",
      "masquerade",
      "static NAT",
      "hairpin NAT",
      "CGNAT",
      "port exhaustion",
      "port allocation",
      "private service endpoints",
      "source allow lists",
      "egress gateway",
      "split-horizon DNS",
      "private DNS zones",
      "DNS64",
      "NAT64",
      "CoreDNS",
      "NodeLocal DNSCache",
      "DNS query volume",
      "UDP 53",
      "TCP 53",
      "NAPI",
      "softirq",
      "RPS",
      "RFS",
      "XPS",
      "IRQ affinity",
      "NIC rings",
      "offloads",
      "GSO",
      "GRO",
      "somaxconn",
      "tcp_max_syn_backlog",
      "ip_local_port_range",
      "SYN backlog",
      "ephemeral port",
      "conntrack table",
      "Ubuntu Server",
      "apt-cache policy",
      "Netplan",
      "UFW",
      "update-ca-certificates",
      "UID",
      "GID",
      "/etc/passwd",
      "/etc/shadow",
      "sudoers",
      "visudo",
      "ACL",
      "OpenSSH",
      "sshd_config",
      "host keys",
      "authorized_keys",
      "PAM",
      "journald",
      "/var/log",
      "logrotate",
      "dmesg",
      "systemd timers",
      "cron",
      "Cronjobs",
      "crontab",
      "anacron",
      "flock",
      "idempotent",
      "rsync",
      "--dry-run",
      "--link-dest",
      "--numeric-ids",
      "scp",
      "Snapshot Backups",
      "crash-consistent",
      "application-consistent",
      "Restore Runbook",
      "timedatectl",
      "systemd-timesyncd",
      "hostnamectl",
      "machine-id",
      "DRM render nodes",
      "RadeonSI",
      "RADV",
      "ROCm",
      "/dev/kfd",
      "rocminfo",
      "rocm-smi",
      "CUDA",
      "NVML",
      "NVIDIA Container Toolkit",
      "Secure Boot",
      "DKMS",
      "nvidia-persistenced",
      "Xid",
      "systemd-networkd",
      "systemd-resolved",
      "network-online.target",
      "systemd-networkd-wait-online",
      ".network",
      ".netdev",
      ".link",
      "socket activation",
      "ListenStream",
      "ListenDatagram",
      "Accept=yes",
      "IPAccounting",
      "PrivateNetwork",
      "RestrictAddressFamilies",
      "evidence preservation",
      "correlation ID",
      "blast radius",
      "exit code",
      "CrashLoopBackOff",
      "ImagePullBackOff",
      "OOMKilled",
      "xDS",
      "PG states",
      "SQLSTATE",
      "idempotency key",
      "backoff with jitter",
      "circuit breaker",
      "dead-letter queue",
      "outbox pattern",
      "partial failure",
      "recursive resolver",
      "TTL",
      "SOA serial",
      "wildcard",
      "DNSKEY",
      "DNS over TLS",
      "DNS over HTTPS",
      "NODATA",
      "SERVFAIL",
      "REFUSED",
      "EDNS",
      "truncated",
      "CAA",
      "PTR",
      "DMARC",
      "kube-apiserver",
      "etcd",
      "kube-scheduler",
      "CoreDNS",
      "kube-dns",
      "cluster.local",
      "dnsPolicy",
      "Corefile",
      "NATS",
      "headless Service",
      "StatefulSet Pod DNS",
      "cluster.advertise",
      "client_advertise",
      "no_advertise",
      "certificate SAN",
      "route peer",
      "publishNotReadyAddresses",
      "SRV records",
      "NodeLocal DNSCache",
      "gossiped server URLs",
      "ExternalDNS",
      "TXT registry",
      "owner ID",
      "domain filter",
      "external-dns.alpha.kubernetes.io/hostname",
      "upsert-only",
      "sync policy",
      "DNS provider API",
      "hosted zone",
      "EndpointSlice",
      "kube-proxy",
      "externalTrafficPolicy",
      "Pod CIDR",
      "hostNetwork",
      "CNI",
      "default-deny",
      "egress",
      "ingressClassName",
      "GatewayClass",
      "HTTPRoute",
      "Ingress",
      "Gateway API",
      "LoadBalancer",
      "CSI",
      "kubeadm upgrade",
      "Version Skew and Order",
      "Worker Node Workflow",
      "Post-Upgrade Validation",
      "Admission webhooks",
      "Operator Deployment and Scaling",
      "Operator Upgrades",
      "leader election",
      "CLUSTERS_ROLLOUT_DELAY",
      "Identity Provider",
      "IdP",
      "authentication",
      "authorization",
      "Service Provider",
      "SAML assertion",
      "AuthnRequest",
      "ACS URL",
      "Entity ID",
      "NameID",
      "OAuth 2.0",
      "authorization code flow",
      "PKCE",
      "access token",
      "refresh token",
      "client credentials",
      "OpenID Connect",
      "ID token",
      "UserInfo endpoint",
      "JWKS",
      "JWT",
      "JWS",
      "issuer",
      "audience",
      "Bearer token",
      "authoritative nameserver",
      "negative caching",
      "split-horizon",
      "Domain Controller",
      "Active Directory",
      "AD DS",
      "_msdcs",
      "_ldap._tcp.dc._msdcs",
      "_kerberos._tcp",
      "Global Catalog",
      "FSMO",
      "dcdiag",
      "repadmin",
      "nltest",
      "Kerberos clock skew",
      "secure dynamic updates",
      "ARP",
      "NIC",
      "OSI",
      "switch",
      "VLAN",
      "802.1Q",
      "trunk",
      "/etc/hosts",
      "getent hosts",
      "policy routing",
      "asymmetric",
      "CIDR",
      "longest-prefix match",
      "source address selection",
      "overlapping private ranges",
      "ICMPv6",
      "Path MTU Discovery",
      "tracepath",
      "fragmentation-needed",
      "UDP 443",
      "QUIC",
      "HTTP/3",
      "DHCP",
      "DORA",
      "DHCP relay",
      "helper address",
      "Option 82",
      "DHCP snooping",
      "lease time",
      "DHCPv6",
      "Router Advertisements",
      "SLAAC",
      "prefix delegation",
      "giaddr",
      "L4",
      "L7",
      "health checks",
      "X-Forwarded-For",
      "PROXY protocol",
      "timeout budget",
      "VPN",
      "IPsec",
      "IKEv2",
      "ESP",
      "NAT-T",
      "traffic selectors",
      "Child SA",
      "SPD",
      "SAD",
      "XFRM",
      "route-based VPN",
      "policy-based",
      "split tunneling",
      "MSS",
      "netfilter",
      "nftables",
      "iptables",
      "iptables-save",
      "ip6tables-save",
      "INPUT",
      "FORWARD",
      "prerouting",
      "postrouting",
      "ESTABLISHED",
      "RELATED",
      "INVALID",
      "DROP",
      "REJECT",
      "UFW",
      "firewalld",
      "forward proxy",
      "reverse proxy",
      "transparent proxy",
      "HTTP CONNECT",
      "NO_PROXY",
      "HTTPS_PROXY",
      "TLS interception",
      "Forwarded",
      "X-Forwarded-Proto",
      "X.509",
      "SAN",
      "SNI",
      "TIME_WAIT",
      "ephemeral ports",
      "listen backlog",
      "HTTP",
      "Istio",
      "service mesh",
      "sidecar mode",
      "ambient mode",
      "ztunnel",
      "waypoint",
      "Envoy",
      "VirtualService",
      "DestinationRule",
      "PeerAuthentication",
      "AuthorizationPolicy",
      "mTLS",
      "Ceph",
      "RADOS",
      "MON",
      "OSD",
      "MDS",
      "RGW",
      "CRUSH",
      "placement group",
      "ceph health",
      "Rook",
      "CephCluster",
      "MVCC",
      "Write-Ahead Logging",
      "EXPLAIN ANALYZE",
      "managed HA",
      "streaming replication",
      "logical replication",
      "replication slots",
      "Logical replication model",
      "logical replication failover",
      "pg_stat_replication",
      "pg_stat_archiver",
      "pg_stat_wal",
      "HA Failover",
      "Split brain",
      "pg_promote",
      "pg_rewind",
      "timeline",
      "zero downtime",
      "CloudNativePG Minor Updates",
      "Blue/Green Logical Replication Runbook",
      "PgBouncer and Connection Draining",
      "Kubernetes Guardrails",
      "pg_upgrade",
      "Sharding",
      "shard key",
      "shard map",
      "cross-shard",
      "postgres_fdw",
      "point-in-time recovery",
      "PITR",
      "pg_verifybackup",
      "pg_dumpall --globals-only",
      "pg_locks",
      "pg_blocking_pids",
      "idle_in_transaction_session_timeout",
      "statement_timeout",
      "lock_timeout",
      "synchronous_commit",
      "remote_apply",
      "archive_command",
      "restore_command",
      "recovery target",
      "High CPU",
      "High RAM",
      "work_mem",
      "PgBouncer",
      "transaction pooling",
      "session pooling",
      "statement pooling",
      "max_client_conn",
      "default_pool_size",
      "cl_waiting",
      "SHOW POOLS",
      "server_reset_query",
      "server_reset_query_always",
      "auth_query",
      "CloudNativePG",
      "Barman Cloud Plugin",
      "OpenSearch",
      "cluster-manager",
      "primary shard",
      "replica shard",
      "Cross-Cluster Replication",
      "cross-cluster replication",
      "allocation awareness",
      "forced awareness",
      "wait_for_active_shards",
      "remote_cluster_client",
      "follower index",
      "leader index",
      "Segment replication",
      "Snapshots and Recovery"
    ].each do |term|
      assert_includes corpus, term
    end
  end

  def test_linux_fundamentals_coverage_is_present
    html = read_site("docs/linux/index.html")
    text = text_content(html)
    search = JSON.parse(read_site("assets/js/search-index.json"))
    linux = search.find { |item| item["title"] == "Linux" }

    refute_nil linux
    assert_includes linux["tags"], "linux"
    assert_includes read_site("index.html"), "Linux"
    assert_includes read_site("knowledge-graph/index.html"), "Linux"

    [
      "fork()",
      "copy-on-write",
      "execve()",
      "Zombie",
      "File descriptors",
      "High CPU",
      "RAM",
      "page cache",
      "Paging",
      "Swap",
      "vm.swappiness",
      "sysctl",
      "cgroups",
      "Pressure Stall Information",
      "amdgpu",
      "NVIDIA",
      "nvidia-smi",
      "persistence mode",
      "OOM killer"
    ].each do |term|
      assert_includes text, term
    end

    assert_includes html, 'class="study-card-grid"'
    assert_operator html.scan('class="study-card"').length, :>=, 8
  end

  def test_theme_script_supports_search_reader_theme_nav_and_live_typography
    script = read_site("assets/js/study.js")

    assert_includes script, "toggle-theme"
    assert_includes script, "toggle-reader"
    refute_includes script, "toggle-runbook"
    refute_includes script, "setRunbookMode"
    assert_includes script, "setSidebarState"
    assert_includes script, "sidebarState"
    assert_includes script, "Show nav"
    assert_includes script, "Hide nav"
    assert_includes script, "mark-complete"
    assert_includes script, "Saved in study progress"
    assert_includes script, "copy-page-link"
    assert_includes script, "renderMermaidDiagrams"
    assert_includes script, "normalizeMermaidDiagram"
    assert_includes script, "openDiagramModal"
    assert_includes script, "closeDiagramModal"
    assert_includes script, "expand-diagram"
    assert_includes script, "diagram-modal"
    assert_includes script, "pre > code.language-mermaid"
    assert_includes script, ".run({ querySelector"
    assert_includes script, "themeVariables"
    assert_includes script, "diagramKind"
    assert_includes script, "ResizeObserver"
    assert_includes script, "collapse-sidebar"
    assert_includes script, "toggle-sidebar"
    assert_includes script, "open-study"
    assert_includes script, "font-family-control"
    assert_includes script, "text-size-control"
    assert_includes script, "search-index.json"
    assert_includes script, "pageProgress"
    assert_includes script, "studyStats"
    assert_includes script, "studyWeakOnly"
    assert_includes script, "studyMissedOnly"
    assert_includes script, "renderPageToc"
    assert_includes script, "addCopyButtons"
    assert_includes script, "searchFilters"
    assert_includes script, "renderGraphFilters"
  end

  def test_css_supports_mobile_responsive_layout_and_reader_mode
    css = read_site("assets/css/study.css")

    assert_includes css, "@media (max-width: 980px)"
    assert_includes css, "@media (max-width: 640px)"
    assert_includes css, ".reader-mode"
    assert_includes css, "html[data-sidebar-state=\"closed\"] .app-shell"
    assert_includes css, "html[data-sidebar-state=\"closed\"] .site-sidebar"
    refute_includes css, ".runbook-mode"
    assert_includes css, ".page-toc"
    assert_includes css, ".copy-code-button"
    assert_includes css, ".path-card"
    assert_includes css, ".lab-card"
    assert_includes css, ".lab-command-examples"
    assert_includes css, ".lab-command-example"
    assert_includes css, ".graph-controls"
    assert_includes css, ".mermaid-frame"
    assert_includes css, ".mermaid-viewport"
    assert_includes css, ".mermaid-tools"
    assert_includes css, ".diagram-modal"
    assert_includes css, ".diagram-modal-viewport"
    assert_includes css, ".diagram-modal-canvas"
    assert_includes css, ".mermaid-frame svg"
    assert_includes css, "data-diagram-layout=\"scroll\""
    assert_includes css, "justify-content: flex-start"
    assert_includes css, "font-size: 17px"
    assert_includes css, "--reader-size"
    assert_includes css, "data-theme=\"dark\""
  end

  def test_sidebar_avatar_renders
    html = read_site("index.html")

    assert_path_exists site_path("assets/img/snow-mountain-avatar.png")
    assert_includes html, 'class="brand-avatar"'
    assert_includes html, 'src="/assets/img/snow-mountain-avatar.png"'
  end

  def test_favicons_are_available
    assert_path_exists site_path("favicon.ico")
    assert_path_exists site_path("favicon.svg")
  end
end
