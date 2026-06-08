---
title: Cloud-to-on-prem pivot techniques
slug: cloud-to-onprem-pivot-techniques
aliases: ["cloud-to-onprem-pivots","cloud-onprem-bridge-attacks"]
date: 2026-06-08
---
{% raw %}

Most red teams think of the cloud as the destination. In hybrid estates it is also a bridge. A cloud control-plane foothold often hands you a free route into the corporate LAN through agents and tunnels that the network team forgot they deployed. This note catalogs the paths I actually use, with the prereq, the action, and the signal a defender should see.

## Mental model

Cloud-to-on-prem pivots come in three flavors:

- **Agent abuse**: cloud-managed agent runs on an on-prem box; you push a command from the control plane.
- **Tunnel abuse**: a network appliance terminates a tunnel into VPC/VNet; you ride it backwards.
- **Identity abuse**: cloud identity syncs back to AD or grants on-prem console access.

If you have not internalized which roles see which surfaces, read [[cloud-identity-mental-model]] first. For the broader cloud-side moves see [[multi-cloud-pivoting]] and [[ssrf-to-cloud]].

## Entra Connect server takeover

The sync server is the crown jewel of any hybrid AD. It holds an account with DCSync-equivalent rights on-prem and a Directory Synchronization Account in Entra.

- **Prereq**: code execution on the Entra Connect host, or DA on the box. Often reached via stale patching or a service account reuse.
- **Action**: extract the AD DS connector credential from the ADSync SQL instance (LocalDB), decrypt with the DPAPI keys on the host, then DCSync. On the cloud side, replay the Sync Account to seed or modify objects. See [[entra-connect-exploitation-2025]] for the 2025-era key wrapping changes.
- **Signal**: 4624 logons to the ADSync service account from non-sync hosts, sudden full sync cycles outside the scheduler, MSOL_* account use from unexpected IPs.

## Azure Arc agent abuse

Arc-enrolled servers expose `Run Command` and extensions from the Azure control plane. If you own a subscription role with `Microsoft.HybridCompute/machines/runCommands/write`, you have SYSTEM on every on-prem box that called home.

- **Prereq**: Contributor (or a custom role with the runCommand verb) on the resource group containing Arc machines. Reader plus the Connected Machine Onboarding role is sometimes enough via re-onboarding.
- **Action**: `az connectedmachine run-command create` with an inline PowerShell payload, or push a custom script extension. Execution runs as `NT AUTHORITY\SYSTEM` (Windows) or root (Linux).
- **Signal**: `himds` service spawning `powershell.exe`/`bash` with an Azure-issued correlation ID, new entries under `C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandHandlerWindows`.

## AWS SSM hybrid activations

`mi-*` instances are on-prem hosts registered to Systems Manager via an activation code. SSM is a SYSTEM-level command channel.

- **Prereq**: IAM principal with `ssm:SendCommand` or `ssm:StartSession` on the hybrid instance, or `ssm:CreateActivation` to enroll new boxes. Combine with [[aws-sts-assume-role]] for cross-account reach.
- **Action**: `aws ssm start-session --target mi-0abc...` for an interactive shell, or `send-command` with `AWS-RunPowerShellScript`. Document execution survives most EDRs that whitelist `amazon-ssm-agent.exe`.
- **Signal**: `ssm-agent` parenting unexpected children, CloudTrail `SendCommand` against `mi-*` targets, session manager logs with non-admin source identities.

## GCP Connect Gateway and OS Login

Connect Gateway brokers `kubectl` and shell traffic to clusters and VMs sitting behind NAT. OS Login pairs IAM with on-prem SSH on Anthos-attached hosts.

- **Prereq**: `roles/gkehub.gatewayAdmin` for cluster pivots, or `roles/compute.osLogin` plus `iam.serviceAccountUser` on an Anthos node.
- **Action**: `gcloud container fleet memberships get-credentials` then `kubectl exec` into pods that mount host paths or run privileged. For OS Login, push an SSH key with `gcloud compute os-login ssh-keys add` and connect through the gateway.
- **Signal**: Connect Agent egress spikes, new `gke-connect` pod restarts, OS Login audit entries for service accounts that never touched the box before.

## Site-to-site VPN policy abuse

The IPsec tunnel is rarely the weak link. The route tables and firewall policies on either side are.

- **Prereq**: write access to the cloud VPN gateway, route table, or the on-prem firewall config (often a Terraform repo, see [[ci-cd-as-cloud-attack-surface]]).
- **Action**: add a route advertising on-prem CIDRs to an attacker-controlled subnet, or relax a `local-traffic-selector` to permit RDP/SMB from a jump VM you control.
- **Signal**: BGP route changes, new `0.0.0.0/0` or wide-CIDR static routes, IPsec SA renegotiations outside maintenance windows.

## ExpressRoute and Direct Connect

Private circuits are flat layer-3 paths once you own a VM inside the peered VNet/VPC. There is no public-internet hop to inspect.

- **Prereq**: shell on any VM in a subnet whose route table points to the gateway. Often a forgotten dev VM.
- **Action**: pivot with [[chisel]], [[ligolo-ng]], or [[ssh-tunneling]] straight at on-prem RFC1918 ranges. NSGs frequently allow east-west by default.
- **Signal**: NetFlow showing cloud VM IPs talking to on-prem domain controllers, sudden Kerberos traffic across the circuit.

## OpenVPN and third-party cloud tunnels

Tailscale, Cloudflare Tunnel, and Zscaler Private Access connectors all run as user-mode agents on on-prem boxes. Compromise the SaaS tenant and you push a new ACL or device.

- **Prereq**: admin on the SaaS console, often via SSO token theft (see [[token-stealing-cloud]]).
- **Action**: enroll an attacker device with broad ACLs, or hijack an existing connector's API key.
- **Signal**: new device enrollments outside MDM, ACL changes in tenant audit logs, connector restarts.

## Defender hardening priorities

Tier-0 the Entra Connect and Arc-enabled servers. Lock `runCommand` and `SendCommand` behind PIM/JIT. Alert on any cloud audit event whose target is a hybrid resource. Treat the cloud control plane as a privileged jump host, because that is what it is.

{% endraw %}
