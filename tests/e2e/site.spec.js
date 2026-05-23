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
  await search.fill("vlan");
  await expect(page.locator("#search-results").getByRole("link", { name: /Switching, VLANs, and Hosts/i })).toBeVisible();
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

test("study mode can start, reveal by clicking the card, score, and reset", async ({ page }) => {
  await page.goto("/docs/networking/");

  await page.getByRole("button", { name: "Study" }).first().click();
  await expect(page.getByRole("dialog", { name: "Study Mode" })).toBeVisible();
  await expect(page.locator(".study-topic-chip").first()).toBeVisible();

  await page.locator("#study-mode-select").selectOption("test");
  await page.locator("#study-size-select").selectOption("10");
  await page.getByRole("button", { name: "Start", exact: true }).click();

  await expect(page.locator("#study-progress-text")).toHaveText("1 / 10");
  const questionText = await page.locator("#study-card-text").textContent();

  await page.locator("#study-stage-card").click();
  await expect(page.locator("#study-card-label")).toHaveText("Answer");
  await expect(page.locator("#study-card-text")).not.toHaveText(questionText || "");

  await page.getByRole("button", { name: "Right" }).click();
  await expect(page.locator("#study-score-text")).toContainText("1 right");

  await page.getByRole("button", { name: "Reset" }).click();
  await expect(page.locator("#study-progress-text")).toHaveText("0 / 0");
  await expect(page.locator("#study-card-text")).toHaveText("Start a study session.");
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
  await expect(article.getByText("PKCE").first()).toBeVisible();

  await page.goto("/docs/databases/postgres/operations-ha/");
  await expect(page.locator("#postgresql-operations-ha-replication-and-recovery")).toBeVisible();
  await expect(article.getByText("replication slots").first()).toBeVisible();
  await expect(article.getByText("pg_verifybackup").first()).toBeVisible();
  await expect(article.getByText("idle_in_transaction_session_timeout").first()).toBeVisible();
  await expect(article.getByText("High CPU").first()).toBeVisible();
  await expect(article.getByText("High RAM").first()).toBeVisible();

  await page.goto("/docs/databases/postgres/pgbouncer/");
  await expect(page.locator("#pgbouncer")).toBeVisible();
  await expect(article.getByText("transaction pooling").first()).toBeVisible();
  await expect(article.getByText("SHOW POOLS").first()).toBeVisible();
  await expect(article.getByText("cl_waiting").first()).toBeVisible();
  await expect(article.getByText("server_reset_query").first()).toBeVisible();

  await page.goto("/docs/dns/domain-controllers/");
  await expect(page.locator("#domain-controllers-and-directory-dns")).toBeVisible();
  await expect(article.getByText("_msdcs").first()).toBeVisible();
  await expect(article.getByText("Global Catalog").first()).toBeVisible();

  await page.goto("/docs/linux/raid-multipath-device-mapper/");
  await expect(page.locator("#raid-multipath-and-device-mapper")).toBeVisible();
  await expect(article.getByText("LUKS").first()).toBeVisible();
  await expect(article.getByText("multipath").first()).toBeVisible();

  await page.goto("/docs/linux/boot-userspace/");
  await expect(page.locator("#linux-boot-and-userspace")).toBeVisible();
  await expect(article.getByText("EFI System Partition").first()).toBeVisible();
  await expect(article.getByText("systemd-boot").first()).toBeVisible();

  await page.goto("/docs/linux/kernel-modules-devices/");
  await expect(page.locator("#linux-kernel-modules-and-devices")).toBeVisible();
  await expect(article.getByText("modprobe").first()).toBeVisible();
  await expect(article.getByText("modalias").first()).toBeVisible();
  await expect(article.getByText("devtmpfs").first()).toBeVisible();

  await page.goto("/docs/linux/storage-health-performance/");
  await expect(page.locator("#linux-storage-health-and-performance")).toBeVisible();
  await expect(article.getByText("SMART").first()).toBeVisible();
  await expect(article.getByText("iostat").first()).toBeVisible();

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

test("mobile navigation opens and links remain usable", async ({ page, isMobile }) => {
  test.skip(!isMobile, "mobile-only coverage");

  await page.goto("/");
  await page.getByRole("button", { name: "Open navigation" }).click();
  await expect(page.getByLabel("Study navigation")).toBeVisible();
  await page.getByRole("link", { name: "Knowledge Graph" }).click();
  await expect(page.getByRole("heading", { name: "Knowledge Graph" })).toBeVisible();
});
