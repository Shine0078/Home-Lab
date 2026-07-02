# Cost & Cloud Analysis

## Overview

This document compares the cost of running the AD-HomeLab on-premises (Hyper-V) versus in the cloud (Azure, AWS). It helps understand when to use each approach and the financial implications.

## On-Premises (Current Setup)

### Hardware Requirements

| Component | Specification | Estimated Cost (USD) |
|-----------|--------------|---------------------|
| Host PC | 16GB RAM, 4+ core CPU, 200GB SSD | $800 - $1,500 |
| Windows 11 Pro license | OEM | $139 - $199 |
| Windows Server 2022 Eval | 180-day eval | $0 |
| Windows 11 Pro (for VMs) | Eval or existing license | $0 |

### Ongoing Costs

| Item | Monthly Cost |
|------|-------------|
| Electricity (host running 24/7) | ~$15 - $25 |
| Internet (existing connection) | $0 (already paying) |
| Maintenance / parts | ~$5 |
| **Total monthly** | **~$20 - $30** |

### Advantages
- No recurring cloud VM costs
- Full control over hardware
- No data egress fees
- Can run offline

### Disadvantages
- Hardware depreciation (~3-5 year lifespan)
- No redundancy (single point of failure)
- Requires physical space and power

---

## Azure (Equivalent Cloud Setup)

### VM Sizing

| VM | Azure Size | vCPU | RAM | OS Disk | Monthly Cost (Pay-As-You-Go) |
|----|-----------|------|-----|---------|------------------------------|
| DC01 | D4s_v5 | 4 | 16GB | 128GB Premium SSD | ~$120/mo |
| WIN11-CLIENT01 | D4s_v5 | 4 | 16GB | 128GB Premium SSD | ~$120/mo |
| WIN11-CLIENT02 | D4s_v5 | 4 | 16GB | 128GB Premium SSD | ~$120/mo |
| **Total** | | | | | **~$360/mo** |

### Additional Azure Costs

| Item | Monthly Cost |
|------|-------------|
| Virtual Network | $0 |
| Public IP (if needed) | ~$3.65 |
| Bandwidth (1GB egress) | ~$0.087 |
| Azure Backup | ~$10/VM = $30 |
| **Total additional** | **~$35** |
| **Grand total Azure** | **~$395/mo** |

### Azure Reserved Instance (1-year)

| VM | Reserved 1-Year | Savings |
|----|----------------|---------|
| D4s_v5 | ~$85/mo | ~29% |
| 3x VMs | ~$255/mo | |
| + Additional costs | ~$35 | |
| **Total reserved** | **~$290/mo** | **~27% savings** |

### Azure Hybrid Benefit
If you have Windows Server licenses with Software Assurance, you can use Azure Hybrid Benefit to reduce VM costs by ~40%:
- 3x D4s_v5 (Linux pricing) = ~$180/mo
- + Additional costs = ~$35
- **Total with Hybrid Benefit: ~$215/mo**

---

## AWS (Equivalent Cloud Setup)

### VM Sizing

| VM | EC2 Instance | vCPU | RAM | OS Disk | Monthly Cost (On-Demand) |
|----|-------------|------|-----|---------|--------------------------|
| DC01 | t3.xlarge | 4 | 16GB | 128GB gp3 | ~$115/mo |
| WIN11-CLIENT01 | t3.xlarge | 4 | 16GB | 128GB gp3 | ~$115/mo |
| WIN11-CLIENT02 | t3.xlarge | 4 | 16GB | 128GB gp3 | ~$115/mo |
| **Total** | | | | | **~$345/mo** |

### AWS Reserved Instance (1-year, no upfront)

| VM | Reserved 1Y | Savings |
|----|------------|---------|
| t3.xlarge | ~$82/mo | ~28% |
| 3x VMs | ~$246/mo | |
| **Total reserved** | **~$246/mo** | **~29% savings** |

---

## Cost Comparison Summary

| Approach | Monthly Cost | Annual Cost | Notes |
|----------|-------------|-------------|-------|
| **On-Prem** | $20 - $30 | $240 - $360 | + initial hardware (~$1,000) |
| **Azure PAYG** | ~$395 | ~$4,740 | No upfront, scale on demand |
| **Azure Reserved** | ~$290 | ~$3,480 | 1-year commitment |
| **Azure Hybrid** | ~$215 | ~$2,580 | Requires existing licenses |
| **AWS PAYG** | ~$345 | ~$4,140 | No upfront |
| **AWS Reserved** | ~$246 | ~$2,952 | 1-year, no upfront |

## Break-Even Analysis

On-prem hardware cost: ~$1,000 (amortized)
- vs Azure PAYG: $1,000 / ($395 - $25) = ~2.7 months
- vs Azure Reserved: $1,000 / ($290 - $25) = ~3.8 months
- vs AWS PAYG: $1,000 / ($345 - $25) = ~3.1 months

**Conclusion**: If the lab runs for more than ~4 months, on-prem is cheaper. For short-term testing (< 3 months), cloud is more cost-effective. For long-term learning and development, on-prem is significantly cheaper.

## When to Use Each

| Scenario | Recommended Platform |
|----------|---------------------|
| Long-term learning/portfolio | On-Prem (Hyper-V) |
| Short-term testing (< 3 months) | Azure or AWS |
| Team collaboration | Azure (shared VN, RBAC) |
| Disaster recovery testing | Cloud (spin up, test, tear down) |
| Production AD deployment | Hybrid (on-prem DC + cloud DC) |
| Cost-sensitive | On-Prem |
| Need scalability | Cloud |
