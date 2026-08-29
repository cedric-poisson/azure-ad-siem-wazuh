<p align="center">
  <a href="README.md">🇫🇷 Français</a> •
  <a href="README.en.md">🇬🇧 English</a>
</p>

# Azure AD Lab — IaC Deployment of an Active Directory Infrastructure

Personal demo project: fully automated provisioning and configuration of an Active Directory infrastructure on Azure, using **OpenTofu** (infra) and **Ansible** (configuration).

Goal: start from scratch and end up with a working Active Directory domain — forest, domain controller, organizational units, group policies, and a client machine joined to the domain — with zero manual steps.

## Architecture

```
Azure (Sweden Central)
└── rg-ad-lab
    ├── Network: VNet (10.0.0.0/16), subnet (10.0.1.0/24), NSG restricted to a single allowed IP
    ├── vm-dc      : Windows Server 2022 — domain controller (lab.local)
    ├── vm-client  : Windows 11 Pro — domain-joined workstation
    └── Storage account: hosts the WinRM bootstrap script
```

**Stack**:
- **OpenTofu** — Azure infrastructure provisioning (network, VMs, WinRM bootstrap)
- **Ansible** (`microsoft.ad`, `ansible.windows`) — AD forest creation, DC promotion, OUs, GPOs, domain join
- **Ansible Vault** — encrypted secrets (DSRM password, domain-join credentials)

## Repo structure

```
terraform/
├── main.tf              # Azure provider, resource group
├── network.tf           # VNet, subnet, NSG
├── vm_dc.tf              # Domain controller VM + WinRM bootstrap
├── vm_client.tf          # Client VM + WinRM bootstrap
├── storage.tf            # Storage account hosting the bootstrap script
├── winrm_bootstrap.ps1   # Script enabling WinRM/HTTPS on first boot
└── variables.tf / outputs.tf / terraform.tfvars (not versioned)

ansible/
├── inventory/hosts.ini   # Inventory (not versioned, contains credentials)
├── group_vars/
│   ├── dc/               # Variables + vault-encrypted secrets (AD forest, DSRM password)
│   └── clients/          # Variables + vault-encrypted secrets (domain join)
├── roles/
│   ├── ad_dc_prep/        # AD-Domain-Services and DNS feature installation
│   ├── ad_domain_create/  # Forest creation + DC promotion
│   ├── ad_ou_gpo/         # Organizational units + group policies
│   └── client_join/       # Client workstation domain join
└── site.yml               # Main playbook
```

## What it deploys

- An Active Directory forest (`lab.local`) on a Windows Server 2022 domain controller
- 4 organizational units: `Direction`, `Commercial`, `Ordinateurs`, `Serveurs`
- 2 group policies (USB restriction, screen lock), linked to their respective OUs
- A Windows 11 workstation joined to the domain, with DNS pointing to the domain controller

## Notes

- No explicit AD functional level was set at forest creation (defaults to `Windows2016Domain`) — no impact for this lab, but worth fixing if the infra were recreated.
- GPO creation relies on raw PowerShell via `win_shell`, as there's no mature official Ansible module for this task yet — OU management, on the other hand, uses the native `microsoft.ad.ou` module.
- Infrastructure is destroyed between work sessions (`tofu destroy`) to keep costs under control.
