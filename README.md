<p align="center">
  <a href="README.md">🇫🇷 Français</a> •
  <a href="README.en.md">🇬🇧 English</a>
</p>

# Azure AD + SIEM Wazuh Lab — Infrastructure Active Directory supervisée, en IaC

Projet personnel de démonstration : provisioning et configuration entièrement automatisés d'une infrastructure Active Directory sur Azure, avec **OpenTofu** (infra) et **Ansible** (configuration) — supervisée par un **SIEM Wazuh** pour la détection d'incidents de sécurité.

Objectif : partir de zéro et obtenir un domaine Active Directory fonctionnel — forêt, contrôleur de domaine, unités d'organisation, stratégies de groupe, poste client joint au domaine — puis y brancher un SIEM capable de remonter et d'alerter sur des événements de sécurité réels (échecs d'authentification, modifications de fichiers sensibles, etc.), sans aucune étape manuelle.

Ce projet prolonge [azure-ad-lab](https://github.com/cedric-poisson/azure-ad-lab), dont il réutilise l'intégralité de la brique AD.

## Architecture

```
Azure (Sweden Central)
└── rg-ad-siem-lab
    ├── Réseau : VNet (10.0.0.0/16), subnet (10.0.1.0/24), NSG restreint à une IP autorisée
    ├── vm-dc      : Windows Server 2022 — contrôleur de domaine (lab.local)
    ├── vm-client  : Windows 11 Pro — poste joint au domaine
    ├── vm-wazuh   : Ubuntu 22.04 — manager + indexer + dashboard Wazuh (all-in-one)
    └── Storage account : hébergement du script de bootstrap WinRM
```

**Stack** :
- **OpenTofu** — provisioning de l'infrastructure Azure (réseau, VMs, bootstrap WinRM)
- **Ansible** (`microsoft.ad`, `ansible.windows`) — création de la forêt AD, promotion en DC, OU, GPO, jonction du domaine
- **Wazuh** (manager, indexer, dashboard) — collecte de logs, FIM, détection d'anomalies
- **Ansible Vault** — secrets chiffrés (mot de passe DSRM, credentials de jonction, credentials Wazuh)

## Structure du repo

```
terraform/
├── main.tf              # provider Azure, resource group
├── network.tf           # VNet, subnet, NSG
├── vm_dc.tf              # VM contrôleur de domaine + bootstrap WinRM
├── vm_client.tf          # VM cliente + bootstrap WinRM
├── vm_wazuh.tf            # VM manager Wazuh
├── storage.tf            # storage account hébergeant le script de bootstrap
├── winrm_bootstrap.ps1   # script d'activation de WinRM/HTTPS au premier boot
└── variables.tf / outputs.tf / terraform.tfvars (non versionné)

ansible/
├── inventory/hosts.ini   # inventaire (non versionné, contient les identifiants)
├── group_vars/
│   ├── dc/               # variables + secrets vaultés (forêt AD, mot de passe DSRM)
│   ├── clients/          # variables + secrets vaultés (jonction du domaine)
│   └── wazuh/            # variables + secrets vaultés (config manager/agents)
├── roles/
│   ├── ad_dc_prep/        # installation des features AD-Domain-Services, DNS
│   ├── ad_domain_create/  # création de la forêt + promotion en DC
│   ├── ad_ou_gpo/         # unités d'organisation + stratégies de groupe
│   ├── client_join/       # jonction du poste client au domaine
│   ├── wazuh_manager/     # installation et configuration du manager Wazuh
│   └── wazuh_agent/       # déploiement des agents sur le DC et le poste client
└── site.yml               # playbook principal
```

## Ce que ça déploie

- Une forêt Active Directory (`lab.local`) sur un contrôleur de domaine Windows Server 2022
- 4 unités d'organisation : `Direction`, `Commercial`, `Ordinateurs`, `Serveurs`
- 2 stratégies de groupe (restriction USB, verrouillage d'écran), liées aux OU correspondantes
- Un poste Windows 11 joint au domaine, avec DNS pointant vers le contrôleur de domaine
- Un manager Wazuh supervisant le DC et le poste client (agents installés, FIM et collecte des logs de sécurité Windows activés)

## Tests de validation

- Enrollment des agents Wazuh (DC + poste client) auprès du manager
- Détection d'un échec d'authentification simulé sur le DC
- Détection d'une modification de fichier surveillé par le FIM

## Notes

- Pas de niveau fonctionnel AD explicite défini à la création de la forêt (reste au défaut `Windows2016Domain`) — sans impact pour ce lab, mais à corriger si l'infra était recréée.
- La création de GPO passe par `win_shell`/PowerShell brut, faute de module Ansible officiel mature pour cette tâche — la gestion des OU, elle, utilise le module natif `microsoft.ad.ou`.
- Infrastructure détruite entre les sessions de travail (`tofu destroy`) pour maîtriser les coûts.
