require "cgi"
require "json"
require "minitest/autorun"
require "yaml"

class SiteTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  COMMAND_BLOCKS = {
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
    "docs/linux/filesystems-io/index.html" => [
      "findmnt",
      "df -h",
      "df -i",
      "lsblk -f",
      "iostat -xz 1",
      "journalctl -k -g 'I/O error|EXT4|XFS|blk|nvme|scsi'"
    ],
    "docs/linux/network-stack/index.html" => [
      "ip addr",
      "ip route",
      "ip rule",
      "ip neigh",
      "ss -tulpen",
      "nft list ruleset",
      "cat /proc/net/softnet_stat"
    ],
    "docs/linux/debian-ubuntu/index.html" => [
      "cat /etc/os-release",
      "uname -a",
      "apt-cache policy",
      "systemctl --failed",
      "journalctl -p warning..alert -b",
      "ls -l /etc/netplan"
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
      "kubectl get pods --all-namespaces",
      "kubectl get events --sort-by=.lastTimestamp"
    ],
    "docs/dns/index.html" => [
      "dig example.com A",
      "dig example.com AAAA",
      "dig +trace example.com",
      "dig @1.1.1.1 example.com",
      "dig NS example.com",
      "dig SOA example.com",
      "dig +dnssec example.com"
    ],
    "docs/dns/resolution-caching/index.html" => [
      "getent hosts example.com",
      "dig example.com A",
      "dig example.com AAAA",
      "dig +trace example.com",
      "dig @1.1.1.1 example.com"
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
    "docs/networking/routing-nat-firewalls/index.html" => [
      "ip route",
      "ip route get 198.51.100.10",
      "ip rule",
      "nft list ruleset",
      "conntrack -S",
      "conntrack -L | head"
    ],
    "docs/networking/switching-vlans-hosts/index.html" => [
      "ip link",
      "bridge link",
      "bridge vlan show",
      "ip -d link show",
      "cat /etc/hosts",
      "getent hosts example.internal"
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
    "docs/kubernetes/storage-upgrades/index.html" => [
      "kubectl get pv,pvc,storageclass,volumesnapshotclass",
      "kubectl describe pvc <claim>",
      "kubectl get volumeattachment",
      "kubeadm upgrade plan",
      "kubectl drain <node> --ignore-daemonsets --delete-emptydir-data",
      "kubectl uncordon <node>"
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
    "docs/databases/postgres/index.html" => [
      "psql -d <database>",
      "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM table_name;",
      "VACUUM (ANALYZE) table_name;"
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

  def test_custom_study_theme_replaces_third_party_theme
    html = read_site("index.html")
    config = File.read(File.join(ROOT, "_config.yml"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))

    refute_includes config, "theme: jekyll-theme-chirpy"
    refute_includes gemfile, "jekyll-theme-chirpy"
    refute_includes html, "jekyll-theme-chirpy"
    assert_includes html, "/assets/css/study.css"
    assert_includes html, "/assets/js/study.js"
    assert_includes html, "StudyGraph"
  end

  def test_sidebar_navigation_theme_toggle_and_reader_controls_render
    html = read_site("docs/databases/postgres/index.html")

    assert_includes html, 'class="site-sidebar"'
    assert_includes html, 'class="study-nav"'
    assert_includes html, "<summary>"
    assert_includes html, 'href="/docs/databases/postgres/"'
    assert_includes html, 'data-action="collapse-sidebar"'
    assert_includes html, 'data-action="toggle-sidebar"'
    assert_includes html, 'id="mode-toggle"'
    assert_includes html, 'data-action="toggle-reader"'
    assert_includes html, 'data-action="open-study"'
    assert_includes html, 'id="study-mode-toggle"'
    assert_includes html, 'id="font-family-control"'
    assert_includes html, 'id="text-size-control"'
  end

  def test_search_index_contains_pages_tags_and_content
    index = JSON.parse(read_site("assets/js/search-index.json"))
    postgres = index.find { |item| item["title"] == "PostgreSQL" }
    ceph = index.find { |item| item["title"] == "Ceph" }
    lvm = index.find { |item| item["title"] == "Linux LVM" }
    systemd = index.find { |item| item["title"] == "systemd" }
    resolv = index.find { |item| item["title"] == "resolv.conf" }
    boot = index.find { |item| item["title"] == "Linux Boot and Userspace" }
    filesystems = index.find { |item| item["title"] == "Linux Filesystems and IO" }
    linux_network = index.find { |item| item["title"] == "Linux Network Stack" }
    dns_cache = index.find { |item| item["title"] == "DNS Resolution and Caching" }
    zones = index.find { |item| item["title"] == "Authoritative DNS and Zones" }
    dnssec = index.find { |item| item["title"] == "DNSSEC and DNS Privacy" }
    packet_path = index.find { |item| item["title"] == "Packet Path" }
    routing = index.find { |item| item["title"] == "Routing, NAT, and Firewalls" }
    switching = index.find { |item| item["title"] == "Switching, VLANs, and Hosts" }
    certificates = index.find { |item| item["title"] == "Certificates and HTTPS" }
    tcp_sockets = index.find { |item| item["title"] == "TCP and Sockets" }
    tcp_tls = index.find { |item| item["title"] == "TCP, TLS, and HTTP" }
    debian = index.find { |item| item["title"] == "Debian and Ubuntu Operations" }
    istio = index.find { |item| item["title"] == "Istio" }
    service_mesh = index.find { |item| item["title"] == "Istio Service Mesh" }

    refute_nil postgres
    refute_nil ceph
    refute_nil lvm
    refute_nil systemd
    refute_nil resolv
    refute_nil boot
    refute_nil filesystems
    refute_nil linux_network
    refute_nil dns_cache
    refute_nil zones
    refute_nil dnssec
    refute_nil packet_path
    refute_nil routing
    refute_nil switching
    refute_nil certificates
    refute_nil tcp_sockets
    refute_nil tcp_tls
    refute_nil debian
    refute_nil istio
    refute_nil service_mesh
    assert_includes postgres["tags"], "databases"
    assert_includes postgres["content"], "EXPLAIN"
    assert_includes ceph["content"], "RADOS"
    assert_includes lvm["content"], "pvmove"
    assert_includes systemd["content"], "journalctl"
    assert_includes resolv["content"], "ndots"
    assert_includes boot["content"], "initramfs"
    assert_includes filesystems["content"], "VFS"
    assert_includes linux_network["content"], "conntrack"
    assert_includes dns_cache["content"], "negative answer"
    assert_includes zones["content"], "SOA serial"
    assert_includes dnssec["content"], "DNSKEY"
    assert_includes packet_path["content"], "qdisc"
    assert_includes routing["content"], "policy routing"
    assert_includes switching["content"], "/etc/hosts"
    assert_includes switching["content"], "802.1Q"
    assert_includes certificates["content"], "update-ca-certificates"
    assert_includes tcp_sockets["content"], "TIME_WAIT"
    assert_includes tcp_tls["content"], "SNI"
    assert_includes debian["content"], "Ubuntu Server"
    assert_includes istio["content"], "ambient mode"
    assert_includes service_mesh["content"], "ztunnel"
    assert_operator index.length, :>=, 29
  end

  def test_tag_index_and_knowledge_graph_render
    tags = read_site("tags/index.html")
    graph = read_site("knowledge-graph/index.html")

    assert_includes tags, 'id="kubernetes"'
    assert_includes tags, "Core Concepts"
    assert_includes tags, 'id="postgres"'
    assert_includes graph, 'class="graph-board"'
    assert_includes graph, 'class="tag-cloud"'
    assert_includes graph, "Kubernetes"
    assert_includes graph, "PostgreSQL"
    assert_includes graph, "CloudNativePG"
    assert_includes graph, "Ceph"
    assert_includes graph, "Rook-Ceph"
    assert_includes graph, "Resolution and Caching"
    assert_includes graph, "Packet Path"
    assert_includes graph, "Boot and Userspace"
    assert_includes graph, "Certificates and HTTPS"
    assert_includes graph, "TCP and Sockets"
    assert_includes graph, "Switching, VLANs, and Hosts"
    assert_includes graph, "Debian and Ubuntu"
    assert_includes graph, "Istio"
    assert_includes graph, "Service Mesh"
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
      "docs/linux/filesystems-io/index.html",
      "docs/linux/network-stack/index.html",
      "docs/linux/debian-ubuntu/index.html",
      "docs/kubernetes/index.html",
      "docs/kubernetes/core-concepts/index.html",
      "docs/kubernetes/networking/index.html",
      "docs/kubernetes/storage-upgrades/index.html",
      "docs/dns/index.html",
      "docs/dns/resolution-caching/index.html",
      "docs/dns/authoritative-zones/index.html",
      "docs/dns/dnssec-privacy/index.html",
      "docs/networking/index.html",
      "docs/networking/packet-path/index.html",
      "docs/networking/routing-nat-firewalls/index.html",
      "docs/networking/switching-vlans-hosts/index.html",
      "docs/networking/certificates-https/index.html",
      "docs/networking/tcp-sockets/index.html",
      "docs/networking/tcp-tls-http/index.html",
      "docs/istio/service-mesh/index.html",
      "docs/ceph/rook-ceph/index.html",
      "docs/databases/postgres/index.html",
      "docs/databases/postgres/cloudnativepg/index.html"
    ].each do |relative_path|
      html = read_site(relative_path)

      assert_includes html, 'class="study-card-grid"', "Expected study cards in #{relative_path}"
      assert_operator html.scan('class="study-card"').length, :>=, 3, "Expected multiple cards in #{relative_path}"
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
      "istio" => "docs/istio/index.html"
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

    %w[linux kubernetes dns networking postgres ceph istio].each do |deck|
      assert_operator decks.fetch(deck).fetch("cards").length, :>=, 50, "Expected at least 50 cards in #{deck} deck"
    end
  end

  def test_generated_study_deck_json_exposes_all_decks
    decks = JSON.parse(read_site("assets/js/study-decks.json"))

    %w[linux kubernetes dns networking postgres ceph istio].each do |deck|
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
    assert_includes html, 'id="study-all-topics"'
    assert_includes html, 'id="study-topic-list"'
    assert_includes html, 'id="study-mode-select"'
    assert_includes html, '<option value="review">Review</option>'
    assert_includes html, '<option value="test">Test</option>'
    assert_includes html, 'id="study-size-select"'
    assert_includes html, '<option value="all">All selected</option>'
    assert_includes html, '<option value="10">10 cards</option>'
    assert_includes html, 'data-action="previous-card"'
    assert_includes html, 'data-action="next-card"'
    assert_includes html, 'data-action="reveal-card"'
    assert_includes html, 'data-action="mark-right"'
    assert_includes html, 'data-action="mark-wrong"'
    assert_includes html, 'data-action="reset-study"'
    assert_includes html, 'id="study-stage-card" role="button" tabindex="0" aria-pressed="false"'

    assert_includes script, "study-decks.json"
    assert_includes script, "openStudy"
    assert_includes script, "selectedStudyDecks"
    assert_includes script, "moveStudyCard"
    assert_includes script, 'studyStageCard.addEventListener("click"'
    assert_includes script, "revealStudyCard();"
    assert_includes script, 'studyStageCard.setAttribute("aria-pressed"'
    assert_includes script, "markStudyCard"
    assert_includes script, "Complete:"

    assert_includes css, ".study-card-grid"
    assert_includes css, "display: none"
    assert_includes css, ".study-modal"
    assert_includes css, ".study-stage-card"
  end

  def test_researched_topic_coverage_is_present
    corpus = [
      "docs/linux/index.html",
      "docs/linux/lvm/index.html",
      "docs/linux/systemd/index.html",
      "docs/linux/resolv-conf/index.html",
      "docs/linux/boot-userspace/index.html",
      "docs/linux/filesystems-io/index.html",
      "docs/linux/network-stack/index.html",
      "docs/linux/debian-ubuntu/index.html",
      "docs/kubernetes/index.html",
      "docs/kubernetes/core-concepts/index.html",
      "docs/kubernetes/networking/index.html",
      "docs/kubernetes/storage-upgrades/index.html",
      "docs/dns/index.html",
      "docs/dns/resolution-caching/index.html",
      "docs/dns/authoritative-zones/index.html",
      "docs/dns/dnssec-privacy/index.html",
      "docs/networking/index.html",
      "docs/networking/packet-path/index.html",
      "docs/networking/routing-nat-firewalls/index.html",
      "docs/networking/switching-vlans-hosts/index.html",
      "docs/networking/certificates-https/index.html",
      "docs/networking/tcp-sockets/index.html",
      "docs/networking/tcp-tls-http/index.html",
      "docs/istio/index.html",
      "docs/istio/service-mesh/index.html",
      "docs/ceph/index.html",
      "docs/ceph/rook-ceph/index.html",
      "docs/databases/postgres/index.html",
      "docs/databases/postgres/cloudnativepg/index.html"
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
      "VFS",
      "inode",
      "page cache",
      "fsync",
      "network namespace",
      "netfilter",
      "conntrack",
      "qdisc",
      "Ubuntu Server",
      "apt-cache policy",
      "Netplan",
      "UFW",
      "update-ca-certificates",
      "recursive resolver",
      "TTL",
      "SOA serial",
      "wildcard",
      "DNSKEY",
      "DNS over TLS",
      "DNS over HTTPS",
      "kube-apiserver",
      "etcd",
      "kube-scheduler",
      "CoreDNS",
      "kube-dns",
      "Ingress",
      "Gateway API",
      "LoadBalancer",
      "CSI",
      "kubeadm upgrade",
      "authoritative nameserver",
      "negative caching",
      "split-horizon",
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
      "CloudNativePG",
      "Barman Cloud Plugin"
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
    assert_includes script, "collapse-sidebar"
    assert_includes script, "toggle-sidebar"
    assert_includes script, "open-study"
    assert_includes script, "font-family-control"
    assert_includes script, "text-size-control"
    assert_includes script, "search-index.json"
  end

  def test_css_supports_mobile_responsive_layout_and_reader_mode
    css = read_site("assets/css/study.css")

    assert_includes css, "@media (max-width: 980px)"
    assert_includes css, "@media (max-width: 640px)"
    assert_includes css, ".reader-mode"
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
