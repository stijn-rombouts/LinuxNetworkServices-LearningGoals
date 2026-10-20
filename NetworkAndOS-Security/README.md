# Network and OS Security Learning Goals

## Table of Contents

- **[Learning Goal 11.6: Cybersecurity Framework Association](11-6/README.md)**
  - Demonstration: Web Server RCE & Container Escape (CVE-2026-31431 Copy Fail)
  - MITRE ATT&CK Framework Mapping & Root Cause Analysis
  - NIST Cybersecurity Framework (CSF 2.0) Implementation & Defenses
  - Proof of Concept & Execution Guide: [`11-6/CVE-2026-31431-Copy-Fail-Container-Escape/`](11-6/CVE-2026-31431-Copy-Fail-Container-Escape/)
- **[Learning Goal 11.7: Role and Components of a Security Operations Center](11-7/README.md)**
  - Comprehensive Theoretical Foundations (Pillars: People, Process, Technology; Roles Tier 1-3; Incident Response Lifecycle)
  - Key Operational Metrics & SLAs (MTTD, MTTR, False Positive Ratio, Dwell Time)
  - Architectural Case Study: Cloud-Native SOC with Microsoft Sentinel (Ingestion, Normalization, KQL Detection, Fusion, SOAR, Workbooks)
  - Multi-Stage Attack Correlation & End-to-End Walkthrough
  - Engineering Trade-offs: Telemetry Costs, Rule Tuning, Human-in-the-Loop SOAR Governance, and Azure Arc Hybrid Reach
- **[Learning Goal 11.10: Endpoint Security Testing & Hardening (CIS Benchmarks & Scanners)](11-10/README.md)**
  - CIS Benchmark Overview & Scanners (`verify_compliance.sh`, Lynis, OpenSCAP)
  - Hands-On Endpoint Security Audit & Baseline Results on Target Host
  - Gap Analysis & Remediation Guide: Fixing Legacy Filesystems, Network Sysctl, and SSH Weaknesses
  - Automated Patching & Verification: Previewing Dry-Runs and Measuring Compliance Score Improvement (47% to 94%)
- **[Learning Goal 11.12: Advanced Network Traffic Analysis in Kubernetes (Kubeshark)](11-12/README.md)**
  - Cloud-Native Packet Analysis Challenges (Pod Churn, CNI Overlays, Encrypted mTLS)
  - Tool Comparison & Selection: Kubeshark (eBPF DPI & Live UI) vs. Isopcap (Isovalent Enterprise)
  - Hands-On Deployment on Debian 13 VM (K3s): Real-Time eBPF Traffic Tapping and Microservices
  - Deep Packet Inspection with KFL: POST Payloads, HTTP 404 Errors, Bearer Tokens, URL Routing, and CoreDNS
  - Security Findings & Architectural Insights: Cleartext Credentials in Transit, NetworkPolicies, and mTLS Recommendations


