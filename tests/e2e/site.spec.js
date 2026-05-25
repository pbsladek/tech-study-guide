const { expect, test } = require("@playwright/test");

test("home page, navigation, and search work", async ({ page, isMobile }) => {
  const searchIndex = page.waitForResponse(/search-index\.json/);
  await page.goto("/");
  await searchIndex;

  await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();
  if (isMobile) {
    await page.getByRole("button", { name: "Open navigation" }).click();
  }
  await expect(page.getByRole("link", { name: "Linux" }).first()).toBeVisible();
  await expect(page.getByRole("link", { name: "Istio" }).first()).toBeVisible();

  const search = page.getByLabel("Search");
  await expect(page.locator("#search-results")).toHaveAttribute("data-ready", "true");
  await search.fill("zero-trust networking");
  await expect(page.locator("#search-results").getByRole("link", { name: /Zero-Trust Networking/i })).toBeVisible();
});

test("reader, theme, and typography controls update the page", async ({ page }) => {
  await page.goto("/docs/networking/");

  await page.getByRole("button", { name: "Theme" }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", /light|dark/);

  await page.getByRole("button", { name: "Reader" }).click();
  await expect(page.locator("body")).toHaveClass(/reader-mode/);

  await page.locator("#font-family-control").selectOption("mono");
  await expect(page.locator("html")).toHaveAttribute("data-font", "mono");

  await page.locator("#text-size-control").fill("115");
  await expect(page.locator("html")).toHaveCSS("--reader-size", "115%");
});

test("study mode can start from the card, use arrow keys, score, and reset", async ({ page }) => {
  await page.goto("/docs/networking/");

  await page.getByRole("button", { name: "Study" }).first().click();
  await expect(page.getByRole("dialog", { name: "Study Mode" })).toBeVisible();
  await expect(page.locator(".study-topic-chip").first()).toBeVisible();

  await page.locator("#study-mode-select").selectOption("test");
  await page.locator("#study-size-select").selectOption("10");
  await expect(page.locator("#study-card-label")).toHaveText("Start quiz");
  await expect(page.locator("#study-card-text")).toHaveText("Start selected cards");

  await page.locator("#study-stage-card").click();

  await expect(page.locator("#study-progress-text")).toHaveText("1 / 10");
  const questionText = await page.locator("#study-card-text").textContent();

  await page.locator("#study-stage-card").press("ArrowDown");
  await expect(page.locator("#study-card-label")).toHaveText("Answer");
  await expect(page.locator("#study-card-text")).not.toHaveText(questionText || "");

  await page.locator("#study-stage-card").press("ArrowRight");
  await expect(page.locator("#study-progress-text")).toHaveText("2 / 10");

  await page.locator("#study-stage-card").press("ArrowLeft");
  await expect(page.locator("#study-progress-text")).toHaveText("1 / 10");

  await page.getByRole("button", { name: "Right" }).click();
  await expect(page.locator("#study-score-text")).toContainText("1 right");

  await page.getByRole("button", { name: "Reset" }).click();
  await expect(page.locator("#study-progress-text")).toHaveText("0 / 0");
  await expect(page.locator("#study-card-text")).toHaveText("Start selected cards");
});

test("topic pages for current coverage render important content", async ({ page }) => {
  const article = page.locator("article.content-card");

  await page.goto("/docs/networking/switching-vlans-hosts/");
  await expect(page.locator("#switching-vlans-and-hosts")).toBeVisible();
  await expect(article.getByText("802.1Q").first()).toBeVisible();
  await expect(article.getByText("DHCP snooping").first()).toBeVisible();
  await expect(article.getByText("/etc/hosts").first()).toBeVisible();

  await page.goto("/docs/networking/dhcp-routers-switches/");
  await expect(page.locator("#dhcp-routers-and-switches")).toBeVisible();
  await expect(article.getByText("DORA").first()).toBeVisible();
  await expect(article.getByText("Option 82").first()).toBeVisible();
  await expect(article.getByText("Router Advertisements").first()).toBeVisible();

  await page.goto("/docs/istio/");
  await expect(page.locator("#istio")).toBeVisible();
  await expect(article.getByText("ambient mode").first()).toBeVisible();
  await expect(article.getByText("ztunnel").first()).toBeVisible();
  await expect(article.getByText("xDS").first()).toBeVisible();

  await page.goto("/docs/istio/traffic-management/");
  await expect(page.locator("#istio-traffic-management")).toBeVisible();
  await expect(article.getByText("VirtualService").first()).toBeVisible();
  await expect(article.getByText("DestinationRule").first()).toBeVisible();

  await page.goto("/docs/istio/security-mtls-policy/");
  await expect(page.locator("#istio-security-mtls-and-policy")).toBeVisible();
  await expect(article.getByText("PeerAuthentication").first()).toBeVisible();
  await expect(article.getByText("AuthorizationPolicy").first()).toBeVisible();

  await page.goto("/docs/istio/gateways-ingress-egress/");
  await expect(page.locator("#istio-gateways-ingress-and-egress")).toBeVisible();
  await expect(article.getByText("TLS Modes").first()).toBeVisible();
  await expect(article.getByText("Egress Control").first()).toBeVisible();

  await page.goto("/docs/istio/zero-downtime-upgrades/");
  await expect(page.locator("#istio-zero-downtime-upgrades-on-kubernetes")).toBeVisible();
  await expect(article.getByText("Canary Control Plane").first()).toBeVisible();
  await expect(article.getByText("Revision Tags").first()).toBeVisible();
  await expect(article.getByText("Gateway Upgrades").first()).toBeVisible();
  await expect(article.getByText("maxUnavailable: 0").first()).toBeVisible();

  await page.goto("/docs/istio/observability-troubleshooting/");
  await expect(page.locator("#istio-observability-and-troubleshooting")).toBeVisible();
  await expect(article.getByText("proxy-status").first()).toBeVisible();
  await expect(article.getByText("response flags").first()).toBeVisible();

  await page.goto("/docs/foundational-study-review/");
  await expect(page.locator("#foundational-study-review")).toBeVisible();
  await expect(article.getByText("Topic Coverage Matrix").first()).toBeVisible();
  await expect(article.getByText("Big 101 Gaps").first()).toBeVisible();
  await expect(article.getByText("data plane").first()).toBeVisible();
  await expect(article.getByText("control plane").first()).toBeVisible();

  await page.goto("/docs/linux/systemd-networking/");
  await expect(article.getByText("VLAN and Bridge Example").first()).toBeVisible();
  await expect(article.getByText("networkctl status").first()).toBeVisible();

  await page.goto("/docs/dns/");
  await expect(article.getByText("Browser Enter-to-Answer Walkthrough").first()).toBeVisible();
  await expect(article.getByText("OS and Stub Resolver Details").first()).toBeVisible();
  await expect(article.getByText("Recursive Resolver Cache-Miss Traversal").first()).toBeVisible();
  await expect(article.getByText("Root, TLD, and Authoritative Referrals").first()).toBeVisible();
  await expect(article.getByText("Address selection").first()).toBeVisible();

  await page.goto("/docs/dns/resolution-caching/");
  await expect(article.getByText("Intermittent DNS Runbook").first()).toBeVisible();
  await expect(article.getByText("dig +tcp").first()).toBeVisible();
  await expect(article.getByText("nslookup Deep Dive").first()).toBeVisible();
  await expect(article.getByText("nslookup Output Interpretation").first()).toBeVisible();

  await page.goto("/docs/networking/cross-layer-incident-runbooks/");
  await expect(article.getByText("HTTP 504").first()).toBeVisible();
  await expect(article.getByText("Node Can Reach Service but Pod Cannot").first()).toBeVisible();

  await page.goto("/docs/networking/request-path/");
  await expect(article.getByText("End-to-End Diagram").first()).toBeVisible();
  await expect(article.getByText("Response Path").first()).toBeVisible();

  await page.goto("/docs/troubleshooting/incident-entrypoints/");
  await expect(article.getByText("DNS works on node but not Pod").first()).toBeVisible();
  await expect(article.getByText("Intermittent 5xx").first()).toBeVisible();

  await page.goto("/docs/networking/packet-path/");
  await expect(article.getByText("Production Packet-Capture Labs").first()).toBeVisible();
  await expect(article.getByText("QUIC blocked").first()).toBeVisible();

  await page.goto("/docs/networking/packet-capture-analysis/");
  await expect(article.getByText("Packet-Capture Interpretation Gallery").first()).toBeVisible();
  await expect(article.getByText("Wireshark Display-Filter Cheatsheet").first()).toBeVisible();

  await page.goto("/docs/kubernetes/networking/");
  await expect(article.getByText("Service Datapath Modes").first()).toBeVisible();
  await expect(article.getByText("Service Datapath Diagrams").first()).toBeVisible();
  await expect(article.getByText("allow-dns-egress").first()).toBeVisible();

  await page.goto("/docs/kubernetes/dns-coredns/");
  await expect(article.getByText("CoreDNS Failure Labs").first()).toBeVisible();
  await expect(article.getByText("EndpointSlice RBAC").first()).toBeVisible();

  await page.goto("/docs/study-paths/");
  await expect(article.getByText("Cross-Layer Incident Response").first()).toBeVisible();
  await expect(article.getByText("Production ML from 101 to Advanced Systems").first()).toBeVisible();
  await expect(article.locator("[data-path-card]").first()).toBeVisible();

  await page.goto("/docs/labs/");
  await expect(article.getByText("Kubernetes DNS Outage").first()).toBeVisible();
  await expect(article.getByText("vLLM Inference Latency Spike").first()).toBeVisible();

  await page.goto("/docs/quality/");
  await expect(article.getByText("Content Quality Dashboard").first()).toBeVisible();
  await expect(article.getByText("Pages Missing References").first()).toBeVisible();

  await page.goto("/docs/glossary/");
  await expect(article.getByText("memory.high").first()).toBeVisible();
  await expect(article.getByText("ALPN").first()).toBeVisible();

  await page.goto("/docs/identity/practical-examples/");
  await expect(article.getByText("OAuth authorization-code token exchange").first()).toBeVisible();

  await page.goto("/docs/databases/practical-examples/");
  await expect(article.getByText("CREATE INDEX CONCURRENTLY").first()).toBeVisible();
  await expect(article.locator(".language-sql").first()).toBeVisible();

  await page.goto("/docs/ceph/practical-examples/");
  await expect(article.getByText("ceph osd pool create").first()).toBeVisible();

  await page.goto("/docs/istio/practical-examples/");
  await expect(article.getByText("VirtualService").first()).toBeVisible();
  await expect(article.locator(".language-yaml").first()).toBeVisible();

  await page.goto("/docs/linux/users-permissions-sudo/");
  await expect(page.locator("#users-permissions-and-sudo")).toBeVisible();
  await expect(article.getByText("/etc/passwd").first()).toBeVisible();
  await expect(article.getByText("visudo").first()).toBeVisible();

  await page.goto("/docs/dns/records-transport-operations/");
  await expect(page.locator("#dns-records-responses-and-transport")).toBeVisible();
  await expect(article.getByText("NODATA").first()).toBeVisible();
  await expect(article.getByText("EDNS").first()).toBeVisible();

  await page.goto("/docs/networking/icmp-mtu-path-testing/");
  await expect(page.locator("#icmp-mtu-and-path-testing")).toBeVisible();
  await expect(article.getByText("Path MTU Discovery").first()).toBeVisible();
  await expect(article.getByText("tracepath").first()).toBeVisible();

  await page.goto("/docs/networking/vpn-ipsec-tunnels/");
  await expect(page.locator("#vpns-and-ipsec-tunnels")).toBeVisible();
  await expect(article.getByText("IKEv2").first()).toBeVisible();
  await expect(article.getByText("traffic selectors").first()).toBeVisible();

  await page.goto("/docs/networking/nat-gateways/");
  await expect(page.locator("#nat-gateways-and-network-address-translation")).toBeVisible();
  await expect(article.getByText("port exhaustion").first()).toBeVisible();
  await expect(article.getByText("hairpin NAT").first()).toBeVisible();
  await expect(article.getByText("PAT").first()).toBeVisible();
  await expect(article.getByText("split-horizon DNS").first()).toBeVisible();
  await expect(article.getByText("NodeLocal DNSCache").first()).toBeVisible();

  await page.goto("/docs/linux/ebpf-tracing/");
  await expect(page.locator("#linux-ebpf-and-tracing")).toBeVisible();
  await expect(article.getByText("bpftrace").first()).toBeVisible();
  await expect(article.getByText("XDP").first()).toBeVisible();

  await page.goto("/docs/linux/memory-pressure-oom/");
  await expect(page.locator("#linux-memory-pressure-and-oom")).toBeVisible();
  await expect(article.getByText("OOM killer").first()).toBeVisible();
  await expect(article.getByText("memory.events").first()).toBeVisible();

  await page.goto("/docs/linux/syscall-debugging/");
  await expect(page.locator("#linux-system-call-debugging")).toBeVisible();
  await expect(article.getByText("errno").first()).toBeVisible();
  await expect(article.getByText("epoll_wait").first()).toBeVisible();
  await expect(article.getByText("What strace Proves").first()).toBeVisible();
  await expect(article.getByText("DNS Through strace").first()).toBeVisible();

  await page.goto("/docs/linux/security-controls/");
  await expect(page.locator("#linux-security-controls")).toBeVisible();
  await expect(article.getByText("seccomp").first()).toBeVisible();
  await expect(article.getByText("AppArmor").first()).toBeVisible();

  await page.goto("/docs/linux/package-boot-recovery/");
  await expect(page.locator("#linux-package-and-boot-recovery")).toBeVisible();
  await expect(article.getByText("GRUB rescue").first()).toBeVisible();
  await expect(article.getByText("update-initramfs").first()).toBeVisible();

  await page.goto("/docs/linux/performance-triage-runbooks/");
  await expect(page.locator("#linux-performance-triage-runbooks")).toBeVisible();
  await expect(article.getByText("High Load, Low CPU").first()).toBeVisible();
  await expect(article.getByText("cgroup throttling").first()).toBeVisible();

  await page.goto("/docs/networking/packet-capture-analysis/");
  await expect(page.locator("#packet-capture-and-analysis")).toBeVisible();
  await expect(article.getByText("tcp.analysis.retransmission").first()).toBeVisible();
  await expect(article.getByText("Rolling Captures").first()).toBeVisible();

  await page.goto("/docs/networking/bgp-dynamic-routing/");
  await expect(page.locator("#bgp-and-dynamic-routing")).toBeVisible();
  await expect(article.getByText("AS path").first()).toBeVisible();
  await expect(article.getByText("anycast").first()).toBeVisible();

  await page.goto("/docs/networking/cloud-networking/");
  await expect(page.locator("#cloud-networking")).toBeVisible();
  await expect(article.getByText("security groups").first()).toBeVisible();
  await expect(article.getByText("overlapping CIDRs").first()).toBeVisible();

  await page.goto("/docs/networking/network-namespaces-virtual-networking/");
  await expect(page.locator("#network-namespaces-and-virtual-networking")).toBeVisible();
  await expect(article.getByText("veth pair").first()).toBeVisible();
  await expect(article.getByText("VXLAN").first()).toBeVisible();

  await page.goto("/docs/networking/ipv6-operations/");
  await expect(page.locator("#ipv6-operations")).toBeVisible();
  await expect(article.getByText("Router Advertisements").first()).toBeVisible();
  await expect(article.getByText("NAT64").first()).toBeVisible();

  await page.goto("/docs/networking/http-proxy-debugging/");
  await expect(page.locator("#http-and-proxy-debugging")).toBeVisible();
  await expect(article.getByText("--resolve api.example.com").first()).toBeVisible();
  await expect(article.getByText("CONNECT host:443").first()).toBeVisible();

  await page.goto("/docs/ml/");
  await expect(page.locator("#machine-learning")).toBeVisible();
  await expect(article.getByRole("link", { name: "ML 101 Foundations" })).toBeVisible();
  await expect(article.getByRole("link", { name: "Transformer Internals" })).toBeVisible();
  await expect(article.getByRole("link", { name: "Fine-Tuning and LoRA" })).toBeVisible();
  await expect(article.getByRole("link", { name: "Retrieval-Augmented Generation" })).toBeVisible();
  await expect(article.getByRole("link", { name: "Serving, Inference, and vLLM" })).toBeVisible();
  await expect(article.getByRole("link", { name: "Advanced Inference and vLLM" })).toBeVisible();
  await expect(article.getByRole("link", { name: "Prompt Operations" })).toBeVisible();

  await page.goto("/docs/ml/ml-101-foundations/");
  await expect(page.locator("#ml-101-foundations")).toBeVisible();
  await expect(article.getByText("When Not To Use ML").first()).toBeVisible();

  await page.goto("/docs/ml/transformers-internals/");
  await expect(page.locator("#transformer-internals")).toBeVisible();
  await expect(article.getByText("KV Cache").first()).toBeVisible();

  await page.goto("/docs/ml/models-weights/");
  await expect(page.locator("#ml-models-types-and-weights")).toBeVisible();
  await expect(article.getByText("Transformers").first()).toBeVisible();
  await expect(article.getByText("tokenizer").first()).toBeVisible();

  await page.goto("/docs/ml/accelerators-gpu-tpu/");
  await expect(page.locator("#ml-accelerators-gpu-and-tpu")).toBeVisible();
  await expect(article.getByText("TPU").first()).toBeVisible();
  await expect(article.getByText("BF16").first()).toBeVisible();

  await page.goto("/docs/ml/pytorch-fundamentals/");
  await expect(page.locator("#pytorch-fundamentals")).toBeVisible();
  await expect(article.getByText("autograd").first()).toBeVisible();
  await expect(article.getByText("nn.Module").first()).toBeVisible();

  await page.goto("/docs/ml/finetuning-lora/");
  await expect(page.locator("#fine-tuning-and-lora")).toBeVisible();
  await expect(article.getByText("LoRA").first()).toBeVisible();
  await expect(article.getByText("Regression set").first()).toBeVisible();

  await page.goto("/docs/ml/rag/");
  await expect(page.locator("#retrieval-augmented-generation")).toBeVisible();
  await expect(article.getByText("chunking").first()).toBeVisible();
  await expect(article.getByText("reranking").first()).toBeVisible();

  await page.goto("/docs/ml/agents/");
  await expect(page.locator("#ml-agents-and-tool-use")).toBeVisible();
  await expect(article.getByText("idempotency").first()).toBeVisible();
  await expect(article.getByText("guardrails").first()).toBeVisible();

  await page.goto("/docs/ml/serving-inference-vllm/");
  await expect(page.locator("#ml-serving-inference-and-vllm")).toBeVisible();
  await expect(article.getByText("PagedAttention").first()).toBeVisible();
  await expect(article.getByText("vLLM Tuning Matrix").first()).toBeVisible();
  await expect(article.getByText("speculative decoding").first()).toBeVisible();

  await page.goto("/docs/ml/advanced-inference-vllm/");
  await expect(page.locator("#advanced-inference-and-vllm")).toBeVisible();
  await expect(article.getByText("Disaggregated prefill").first()).toBeVisible();
  await expect(article.getByText("KV-Cache Memory Math").first()).toBeVisible();

  await page.goto("/docs/ml/observability-incident-response/");
  await expect(page.locator("#ml-observability-and-incident-response")).toBeVisible();
  await expect(article.getByText("Incident Runbook").first()).toBeVisible();
  await expect(article.getByText("quality monitoring").first()).toBeVisible();

  await page.goto("/docs/ml/data-pipelines-feature-stores/");
  await expect(page.locator("#ml-data-pipelines-and-feature-stores")).toBeVisible();
  await expect(article.getByText("train/serve skew").first()).toBeVisible();
  await expect(article.getByText("Data Quality Gates").first()).toBeVisible();

  await page.goto("/docs/ml/evaluation-ci-cd/");
  await expect(page.locator("#ml-evaluation-and-cicd")).toBeVisible();
  await expect(article.getByText("golden set").first()).toBeVisible();
  await expect(article.getByText("Release Pipeline").first()).toBeVisible();

  await page.goto("/docs/ml/security-privacy/");
  await expect(page.locator("#ml-security-and-privacy")).toBeVisible();
  await expect(article.getByText("prompt injection").first()).toBeVisible();
  await expect(article.getByText("tenant isolation").first()).toBeVisible();

  await page.goto("/docs/ml/prompt-operations/");
  await expect(page.locator("#ml-prompt-operations")).toBeVisible();
  await expect(article.getByText("structured outputs").first()).toBeVisible();
  await expect(article.getByText("Prompt Release Runbook").first()).toBeVisible();

  await page.goto("/docs/ml/alignment-evaluation/");
  await expect(page.locator("#ml-alignment-and-evaluation")).toBeVisible();
  await expect(article.getByText("RLHF").first()).toBeVisible();
  await expect(article.getByText("DPO").first()).toBeVisible();

  await page.goto("/docs/ml/explainability/");
  await expect(page.locator("#ml-explainability")).toBeVisible();
  await expect(article.getByText("SHAP").first()).toBeVisible();
  await expect(article.getByText("model card").first()).toBeVisible();

  await page.goto("/docs/networking/firewalls-iptables-netfilter/");
  await expect(page.locator("#firewalls-iptables-and-netfilter")).toBeVisible();
  await expect(article.getByText("iptables-save").first()).toBeVisible();
  await expect(article.getByText("conntrack").first()).toBeVisible();

  await page.goto("/docs/networking/proxies-forward-reverse/");
  await expect(page.locator("#forward-and-reverse-proxies")).toBeVisible();
  await expect(article.getByText("CONNECT").first()).toBeVisible();
  await expect(article.getByText("NO_PROXY").first()).toBeVisible();

  await page.goto("/docs/troubleshooting/");
  await expect(page.locator("#troubleshooting-and-error-handling")).toBeVisible();
  await expect(article.getByText("CrashLoopBackOff").first()).toBeVisible();
  await expect(article.getByText("SQLSTATE").first()).toBeVisible();
  await expect(article.getByText("dead-letter queue").first()).toBeVisible();
  await expect(article.getByText("Universal Method").first()).toBeVisible();

  await page.goto("/docs/kubernetes/core-concepts/");
  await expect(page.locator("#kubernetes-core-concepts")).toBeVisible();
  await expect(article.getByText("API Machinery").first()).toBeVisible();
  await expect(article.getByText("CustomResourceDefinitions").first()).toBeVisible();
  await expect(article.getByText("QoS").first()).toBeVisible();

  await page.goto("/docs/kubernetes/troubleshooting/");
  await expect(page.locator("#kubernetes-troubleshooting")).toBeVisible();
  await expect(article.getByText("Pod Failure Workflow").first()).toBeVisible();
  await expect(article.getByText("Service and DNS Workflow").first()).toBeVisible();
  await expect(article.getByText("Evidence Capture").first()).toBeVisible();
  await expect(article.getByText("PVC pending").first()).toBeVisible();

  await page.goto("/docs/kubernetes/dns-coredns/");
  await expect(page.locator("#kubernetes-dns-and-coredns")).toBeVisible();
  await expect(article.getByText("ndots").first()).toBeVisible();
  await expect(article.getByText("Corefile").first()).toBeVisible();

  await page.goto("/docs/kubernetes/nats-dns-kubernetes/");
  await expect(page.locator("#nats-dns-and-kubernetes-networking")).toBeVisible();
  await expect(article.getByText("headless Service").first()).toBeVisible();
  await expect(article.getByText("cluster.advertise").first()).toBeVisible();
  await expect(article.getByText("publishNotReadyAddresses").first()).toBeVisible();
  await expect(article.getByText("gossiped server URLs").first()).toBeVisible();
  await expect(article.getByText("NetworkPolicy").first()).toBeVisible();

  await page.goto("/docs/kubernetes/external-dns/");
  await expect(page.locator("#kubernetes-externaldns")).toBeVisible();
  await expect(article.getByText("TXT registry").first()).toBeVisible();
  await expect(article.getByText("external-dns.alpha.kubernetes.io/hostname").first()).toBeVisible();

  await page.goto("/docs/kubernetes/network-policy/");
  await expect(page.locator("#kubernetes-networkpolicy")).toBeVisible();
  await expect(article.getByText("default-deny").first()).toBeVisible();
  await expect(article.getByText("CNI plugin").first()).toBeVisible();

  await page.goto("/docs/kubernetes/storage-upgrades/");
  await expect(page.locator("#kubernetes-storage-and-upgrades")).toBeVisible();
  await expect(article.getByText("Upgrade Inventory").first()).toBeVisible();
  await expect(article.getByText("Version Skew and Order").first()).toBeVisible();
  await expect(article.getByText("Worker Node Workflow").first()).toBeVisible();
  await expect(article.getByText("Post-Upgrade Validation").first()).toBeVisible();
  await expect(article.getByText("Managed Kubernetes").first()).toBeVisible();

  await page.goto("/docs/identity/");
  await expect(page.locator("#identity-and-access")).toBeVisible();
  await expect(article.getByText("Identity Provider").first()).toBeVisible();
  await expect(article.getByText("authentication").first()).toBeVisible();

  await page.goto("/docs/identity/auth-protocols/");
  await expect(page.locator("#idp-saml-jwt-oauth-and-oidc")).toBeVisible();
  await expect(article.getByText("SAML").first()).toBeVisible();
  await expect(article.getByText("OAuth 2.0").first()).toBeVisible();
  await expect(article.getByText("OpenID Connect").first()).toBeVisible();
  await expect(article.getByText("JWT").first()).toBeVisible();
  await expect(article.getByText("IdP session cookie").first()).toBeVisible();
  await expect(article.getByText("Key Rotation and JWKS").first()).toBeVisible();
  await expect(article.getByText("PKCE").first()).toBeVisible();

  await page.goto("/docs/databases/");
  await expect(page.locator("#databases")).toBeVisible();
  await expect(article.getByText("ACID").first()).toBeVisible();
  await expect(article.getByText("B-trees").first()).toBeVisible();
  await expect(article.getByText("Learning Path").first()).toBeVisible();
  await expect(article.getByText("Choosing the Right Tool Shape").first()).toBeVisible();

  await page.goto("/docs/databases/postgres/operations-ha/");
  await expect(page.locator("#postgresql-operations-ha-replication-and-recovery")).toBeVisible();
  await expect(article.getByText("replication slots").first()).toBeVisible();
  await expect(article.getByText("HA Failover").first()).toBeVisible();
  await expect(article.getByText("Sharding").first()).toBeVisible();
  await expect(article.getByText("shard key").first()).toBeVisible();
  await expect(article.getByText("pg_verifybackup").first()).toBeVisible();
  await expect(article.getByText("idle_in_transaction_session_timeout").first()).toBeVisible();
  await expect(article.getByText("High CPU").first()).toBeVisible();
  await expect(article.getByText("High RAM").first()).toBeVisible();

  await page.goto("/docs/databases/postgres/zero-downtime-upgrades/");
  await expect(page.locator("#postgresql-zero-downtime-upgrades-on-kubernetes")).toBeVisible();
  await expect(article.getByText("CloudNativePG Minor Updates").first()).toBeVisible();
  await expect(article.getByText("Blue/Green Logical Replication Runbook").first()).toBeVisible();
  await expect(article.getByText("PgBouncer and Connection Draining").first()).toBeVisible();
  await expect(article.getByText("Kubernetes Guardrails").first()).toBeVisible();
  await expect(article.getByText("pg_upgrade").first()).toBeVisible();

  await page.goto("/docs/databases/postgres/pgbouncer/");
  await expect(page.locator("#pgbouncer")).toBeVisible();
  await expect(article.getByText("transaction pooling").first()).toBeVisible();
  await expect(article.getByText("SHOW POOLS").first()).toBeVisible();
  await expect(article.getByText("cl_waiting").first()).toBeVisible();
  await expect(article.getByText("server_reset_query").first()).toBeVisible();

  await page.goto("/docs/databases/postgres/cloudnativepg/");
  await expect(page.locator("#cloudnativepg")).toBeVisible();
  await expect(article.getByText("Operator Deployment and Scaling").first()).toBeVisible();
  await expect(article.getByText("Operator Upgrades").first()).toBeVisible();
  await expect(article.getByText("leader election").first()).toBeVisible();
  await expect(article.getByText("CLUSTERS_ROLLOUT_DELAY").first()).toBeVisible();
  await expect(article.getByText("ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES").first()).toBeVisible();

  await page.goto("/docs/databases/opensearch/");
  await expect(page.locator("#opensearch-operations-replication-sharding-and-ha")).toBeVisible();
  await expect(article.getByText("Cross-Cluster Replication").first()).toBeVisible();
  await expect(article.getByText("primary shard").first()).toBeVisible();
  await expect(article.getByText("replica shard").first()).toBeVisible();
  await expect(article.getByText("allocation awareness").first()).toBeVisible();
  await expect(article.getByText("Snapshots and Recovery").first()).toBeVisible();

  await page.goto("/docs/dns/domain-controllers/");
  await expect(page.locator("#domain-controllers-and-directory-dns")).toBeVisible();
  await expect(article.getByText("_msdcs").first()).toBeVisible();
  await expect(article.getByText("Global Catalog").first()).toBeVisible();

  await page.goto("/docs/linux/raid-multipath-device-mapper/");
  await expect(page.locator("#raid-multipath-and-device-mapper")).toBeVisible();
  await expect(article.getByText("LUKS").first()).toBeVisible();
  await expect(article.getByText("multipath").first()).toBeVisible();

  await page.goto("/docs/linux/storage-drives-raid-database-performance/");
  await expect(page.locator("#storage-drives-raid-and-database-performance")).toBeVisible();
  await expect(article.getByText("RAID 10").first()).toBeVisible();
  await expect(article.getByText("RAID 0+1").first()).toBeVisible();
  await expect(article.getByText("RAID Failure Modes").first()).toBeVisible();
  await expect(article.getByText("LVM With RAID").first()).toBeVisible();
  await expect(article.getByText("Disk Failure Recovery").first()).toBeVisible();
  await expect(article.getByText("PostgreSQL Storage Mapping").first()).toBeVisible();
  await expect(article.getByText("Elasticsearch Storage Mapping").first()).toBeVisible();

  await page.goto("/docs/linux/scheduled-automation/");
  await expect(page.locator("#scheduled-automation")).toBeVisible();
  await expect(article.getByText("Cronjobs").first()).toBeVisible();
  await expect(article.getByText("flock").first()).toBeVisible();
  await expect(article.getByText("anacron").first()).toBeVisible();

  await page.goto("/docs/linux/backup-transfer-rsync-scp-snapshots/");
  await expect(page.locator("#linux-backup-and-file-transfer")).toBeVisible();
  await expect(article.getByText("rsync").first()).toBeVisible();
  await expect(article.getByText("Snapshot Backups").first()).toBeVisible();
  await expect(article.getByText("scp").first()).toBeVisible();
  await expect(article.getByText("Restore Runbook").first()).toBeVisible();

  await page.goto("/docs/linux/boot-userspace/");
  await expect(page.locator("#linux-boot-and-userspace")).toBeVisible();
  await expect(article.getByText("EFI System Partition").first()).toBeVisible();
  await expect(article.getByText("systemd-boot").first()).toBeVisible();

  await page.goto("/docs/linux/network-boot-automated-provisioning/");
  await expect(page.locator("#network-boot-and-automated-provisioning")).toBeVisible();
  await expect(article.getByText("PXE").first()).toBeVisible();
  await expect(article.getByText("iPXE").first()).toBeVisible();
  await expect(article.getByText("Ubuntu autoinstall").first()).toBeVisible();
  await expect(article.getByText("reinstall loops").first()).toBeVisible();

  await page.goto("/docs/linux/kernel-modules-devices/");
  await expect(page.locator("#linux-kernel-modules-and-devices")).toBeVisible();
  await expect(article.getByText("modprobe").first()).toBeVisible();
  await expect(article.getByText("modalias").first()).toBeVisible();
  await expect(article.getByText("devtmpfs").first()).toBeVisible();

  await page.goto("/docs/linux/storage-health-performance/");
  await expect(page.locator("#linux-storage-health-and-performance")).toBeVisible();
  await expect(article.getByText("SMART").first()).toBeVisible();
  await expect(article.getByText("iostat").first()).toBeVisible();

  await page.goto("/docs/dns/resolution-caching/");
  await expect(page.locator("#dns-resolution-and-caching")).toBeVisible();
  await expect(article.getByText("Stub, Recursive, and Authoritative").first()).toBeVisible();
  await expect(article.getByText("bailiwick").first()).toBeVisible();

  await page.goto("/docs/networking/certificates-https/");
  await expect(page.locator("#certificates-and-https")).toBeVisible();
  await expect(article.getByText("Chain Validation Checklist").first()).toBeVisible();
  await expect(article.getByText("Certificate Management Examples").first()).toBeVisible();
  await expect(article.getByText("openssl genpkey").first()).toBeVisible();
  await expect(article.getByText("certbot renew --dry-run").first()).toBeVisible();
  await expect(article.getByText("kind: ClusterIssuer").first()).toBeVisible();
  await expect(article.getByText("server-csr.cnf").first()).toBeVisible();
  await expect(article.getByText("mTLS").first()).toBeVisible();

  await page.goto("/docs/ceph/");
  await expect(page.locator("#ceph-storage-and-management")).toBeVisible();
  await expect(article.getByText("Client IO Path").first()).toBeVisible();
  await expect(article.getByText("erasure-coded pool").first()).toBeVisible();

  await page.goto("/docs/ceph/rados-crush-placement/");
  await expect(page.locator("#ceph-rados-crush-and-placement")).toBeVisible();
  await expect(article.getByText("PG autoscaler").first()).toBeVisible();
  await expect(article.getByText("acting set").first()).toBeVisible();

  await page.goto("/docs/ceph/block-file-object/");
  await expect(page.locator("#ceph-block-file-and-object-interfaces")).toBeVisible();
  await expect(article.getByText("RBD").first()).toBeVisible();
  await expect(article.getByText("CephFS").first()).toBeVisible();
  await expect(article.getByText("RGW").first()).toBeVisible();

  await page.goto("/docs/ceph/operations-recovery/");
  await expect(page.locator("#ceph-operations-and-recovery")).toBeVisible();
  await expect(article.getByText("Recovery and Backfill").first()).toBeVisible();
  await expect(article.getByText("noout").first()).toBeVisible();

  await page.goto("/docs/ceph/performance-capacity/");
  await expect(page.locator("#ceph-performance-and-capacity")).toBeVisible();
  await expect(article.getByText("BlueStore").first()).toBeVisible();
  await expect(article.getByText("rados bench").first()).toBeVisible();

  await page.goto("/docs/linux/containerization-oci-vms/");
  await expect(page.locator("#containerization-oci-and-vms")).toBeVisible();
  await expect(article.getByText("OCI").first()).toBeVisible();
  await expect(article.getByText("cgroups").first()).toBeVisible();
  await expect(article.getByText("overlayfs").first()).toBeVisible();
  await expect(article.getByText("copy-up").first()).toBeVisible();
  await expect(article.getByText("cgroup v2").first()).toBeVisible();
  await expect(article.getByText("cpu.max").first()).toBeVisible();
  await expect(article.getByText("Linux bridge").first()).toBeVisible();
  await expect(article.getByText("docker0").first()).toBeVisible();
  await expect(article.getByText("veth pair").first()).toBeVisible();
  await expect(article.getByText("MASQUERADE").first()).toBeVisible();
  await expect(article.getByText("DNAT").first()).toBeVisible();
  await expect(article.getByText("VXLAN").first()).toBeVisible();
  await expect(article.getByText("KVM").first()).toBeVisible();
  await expect(article.getByText("Hyper-V isolation").first()).toBeVisible();

  await page.goto("/docs/linux/mount-namespaces-propagation/");
  await expect(page.locator("#linux-mount-namespaces-and-propagation")).toBeVisible();
  await expect(article.getByText("mountinfo").first()).toBeVisible();
  await expect(article.getByText("nsenter").first()).toBeVisible();

  await page.goto("/docs/linux/sockets-ipc/");
  await expect(page.locator("#linux-sockets-and-ipc")).toBeVisible();
  await expect(article.getByText("Unix domain sockets").first()).toBeVisible();
  await expect(article.getByText("sockstat").first()).toBeVisible();

  await page.goto("/docs/linux/processes-threads/");
  await expect(page.locator("#linux-processes-and-threads")).toBeVisible();
  await expect(article.getByText("thread group").first()).toBeVisible();
  await expect(article.getByText("PID 1").first()).toBeVisible();

  await page.goto("/docs/linux/gpu-drivers/");
  await expect(page.locator("#linux-gpu-drivers")).toBeVisible();
  await expect(article.getByText("ROCm").first()).toBeVisible();
  await expect(article.getByText("RADV").first()).toBeVisible();
  await expect(article.getByText("nvidia-smi").first()).toBeVisible();
  await expect(article.getByText("Secure Boot").first()).toBeVisible();

  await page.goto("/docs/linux/kernel-network-performance/");
  await expect(page.locator("#linux-kernel-network-performance")).toBeVisible();
  await expect(article.getByText("NAPI").first()).toBeVisible();
  await expect(article.getByText("softnet_stat").first()).toBeVisible();

  await page.goto("/docs/linux/systemd-networking/");
  await expect(page.locator("#systemd-networking")).toBeVisible();
  await expect(article.getByText("network-online.target").first()).toBeVisible();
  await expect(article.getByText("systemd-networkd").first()).toBeVisible();
});

test("page tools, graph filters, and code copy controls render", async ({ page }) => {
  await page.goto("/docs/kubernetes/dns-coredns/");

  await expect(page.locator("#page-toc")).toBeVisible();
  await expect(page.locator(".copy-code-button").first()).toBeVisible();
  await expect(page.getByRole("button", { name: "Mark complete" })).toBeVisible();

  await page.getByRole("button", { name: "Runbook mode" }).click();
  await expect(page.locator("body")).toHaveClass(/runbook-mode/);

  await page.getByRole("button", { name: "Mark complete" }).click();
  await expect(page.getByRole("button", { name: "Complete" })).toBeVisible();

  await page.goto("/knowledge-graph/");
  await expect(page.locator("#graph-filter")).toBeVisible();
  await page.locator("#graph-filter").fill("postgres");
  await expect(page.locator("[data-graph-node]").filter({ hasText: "Databases" })).toBeVisible();
  await page.locator("#graph-filter").fill("");
  await page.getByRole("button", { name: "Machine Learning" }).click();
  await expect(page.locator("[data-graph-node]").filter({ hasText: "Machine Learning" })).toBeVisible();
});

test("mobile navigation opens and links remain usable", async ({ page, isMobile }) => {
  test.skip(!isMobile, "mobile-only coverage");

  await page.goto("/");
  await page.getByRole("button", { name: "Open navigation" }).click();
  await expect(page.getByLabel("Study navigation")).toBeVisible();
  await page.getByRole("link", { name: "Knowledge Graph" }).click();
  await expect(page.getByRole("heading", { name: "Knowledge Graph" })).toBeVisible();
});
