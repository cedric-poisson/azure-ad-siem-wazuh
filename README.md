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
└── rg-ad-wazuh-lab
    ├── Réseau : VNet (10.0.0.0/16), subnet (10.0.1.0/24), NSG restreint à une IP autorisée
    ├── vm-dc      : Windows Server 2022 — contrôleur de domaine (lab.local)
    ├── vm-client  : Windows 11 Pro — poste joint au domaine
    ├── vm-wazuh   : Ubuntu 22.04 — manager + indexer + dashboard Wazuh (all-in-one)
    └── Storage account : hébergement des scripts de bootstrap
```

**Stack** :
- **OpenTofu** — provisioning de l'infrastructure Azure (réseau, VMs, bootstrap)
- **Ansible** (`microsoft.ad`, `ansible.windows`, `community.windows`) — création de la forêt AD, promotion en DC, OU, GPO, jonction du domaine, déploiement Wazuh
- **Wazuh** (manager, indexer, dashboard) — collecte de logs, détection d'anomalies, mapping MITRE ATT&CK
- **Ansible Vault** — secrets chiffrés (mot de passe DSRM, credentials de jonction)

## Structure du repo

```
terraform/
├── main.tf                # provider Azure, resource group
├── network.tf             # VNet, subnet, NSG
├── vm_dc.tf                # VM contrôleur de domaine + bootstrap WinRM
├── vm_client.tf            # VM cliente + bootstrap WinRM
├── vm_wazuh.tf              # VM manager Wazuh
├── storage.tf              # storage account hébergeant les scripts de bootstrap
├── winrm_bootstrap.ps1     # script d'activation de WinRM/HTTPS au premier boot
├── wazuh_bootstrap.sh      # script d'installation Wazuh all-in-one au premier boot
└── variables.tf / outputs.tf / terraform.tfvars (non versionné)

ansible/
├── inventory/hosts.ini     # inventaire (non versionné, contient les identifiants)
├── group_vars/
│   ├── all.yml             # variables partagées par tous les hôtes (IP privée du manager Wazuh)
│   ├── dc/                 # variables + secrets vaultés (forêt AD, mot de passe DSRM)
│   ├── clients/             # variables + secrets vaultés (jonction du domaine)
│   └── wazuh/               # variables non sensibles (ports, IP du manager)
├── roles/
│   ├── ad_dc_prep/          # installation des features AD-Domain-Services, DNS
│   ├── ad_domain_create/    # création de la forêt + promotion en DC
│   ├── ad_ou_gpo/           # unités d'organisation + stratégies de groupe
│   ├── client_join/         # configuration DNS + jonction du poste client au domaine
│   ├── wazuh_manager/       # installation et vérification du manager Wazuh
│   └── wazuh_agent/         # déploiement des agents sur le DC et le poste client
└── site.yml                 # playbook principal
```

## Ce que ça déploie

- Une forêt Active Directory (`lab.local`) sur un contrôleur de domaine Windows Server 2022
- 4 unités d'organisation : `Direction`, `Commercial`, `Ordinateurs`, `Serveurs`
- 2 stratégies de groupe (restriction USB, verrouillage d'écran), liées aux OU correspondantes
- Un poste Windows 11 joint au domaine
- Un manager Wazuh supervisant le DC et le poste client (agents installés et actifs, collecte des logs de sécurité Windows)

## Tests de validation effectués

- ✅ Enrollment des agents Wazuh (DC + poste client) auprès du manager — statut "Active" confirmé
- ✅ Détection d'un échec d'authentification simulé (tentative RDP avec mauvais mot de passe) — alerte remontée et classifiée (MITRE ATT&CK T1531, règle Wazuh 60122, niveau 5), visible dans le dashboard
- ⏳ FIM (File Integrity Monitoring) — fonctionnel mais détection différée : les dossiers surveillés par défaut sur les hôtes Windows n'ont pas de scan temps réel (`realtime`), la détection dépend du prochain cycle de scan périodique

## Prérequis pour déployer ce lab

Ce repo est public mais volontairement incomplet : les secrets et la configuration propre à un environnement (credentials Azure, mots de passe AD, mot de passe admin du dashboard Wazuh) ne sont jamais versionnés. Pour déployer ce lab depuis un clone, il faut recréer localement :

**Côté Terraform** — un fichier `terraform/terraform.tfvars` (non fourni), avec au minimum :
```hcl
admin_username = "azureadmin"
admin_password = "..."
my_ip           = "x.x.x.x/32"
```

**Côté Ansible** — un inventaire `ansible/inventory/hosts.ini` (non fourni) référençant les IP publiques générées par Terraform (`tofu output`), avec un groupe par rôle (`dc`, `clients`, `wazuh`), et un mot de passe de vault (choisi librement à la création du premier fichier vaulté du projet) :
```bash
cd ansible/
ansible-vault create group_vars/dc/vault.yml
# puis y définir : ad_safe_mode_password: "..."
ansible-vault create group_vars/clients/vault.yml
# puis y définir : vault_ad_join_password: "..."
```
Le même mot de passe de vault déverrouille tous les fichiers `group_vars/*/vault.yml` du repo.

**Mot de passe admin Wazuh** — généré aléatoirement à l'installation (non versionné, régénéré à chaque redéploiement puisque l'infra est détruite entre les sessions). Récupérable après déploiement via :
```bash
ssh azureadmin@<ip-publique-vm-wazuh>
sudo tar -O -xf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt | grep -A1 "'admin'" | grep 'indexer_password'
```

**Authentification Azure** — ce projet suppose un service principal déjà configuré (variables d'environnement `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`), non versionné pour les mêmes raisons.

Sans ces éléments, `tofu apply` et `ansible-playbook site.yml` échoueront proprement en demandant les valeurs manquantes — c'est le comportement attendu.

## Notes / leçons apprises

- **Quota Azure (abonnement étudiant)** : `standardDSv3Family` limité à 4 vCPU dans `swedencentral` — la VM Wazuh a été basculée en `Standard_B2s_v2` (famille de quota distincte) pour libérer de la marge pour les VMs Windows.
- **DNS et ordre de démarrage** : configurer le DNS d'un client vers le contrôleur de domaine *dès sa création* (au niveau Terraform, via `dns_servers` sur la NIC) casse la résolution de noms publics tant que le DC n'a pas encore de service DNS opérationnel (installé par Ansible, après coup) — l'extension de bootstrap échoue alors à télécharger son script. Correction : DNS par défaut à la création (Terraform), bascule vers le DC uniquement juste avant la jonction au domaine (tâche Ansible dédiée dans `client_join`).
- **Extension `CustomScript` (Linux) vs `CustomScriptExtension` (Windows)** : contrairement à son équivalent Windows, l'extension Linux n'accepte pas de propriété `scriptHash` dans son bloc `settings` — elle est stricte sur le schéma JSON attendu.
- **`become` et PowerShell** : le mécanisme `become` (sudo) d'Ansible est incompatible avec la connexion WinRM — ne jamais l'activer globalement dans un play mixte Linux/Windows, seulement sur les plays ciblant des hôtes Linux.
- **Variables de groupe et portée** : une variable nécessaire à plusieurs groupes d'hôtes différents (ex. l'IP du manager Wazuh, utilisée à la fois par le rôle `wazuh_agent` sur `dc`/`clients` et par la configuration du manager lui-même) doit être définie dans `group_vars/all.yml`, pas dans le `group_vars` d'un groupe spécifique — Ansible ne charge que les variables du ou des groupes auxquels un hôte appartient.
- **Réinstallation idempotente et configuration** : `win_package` ne réexécute pas les arguments d'installation (dont l'adresse du manager Wazuh) si le paquet est déjà présent — un changement de cette valeur nécessite une tâche dédiée de mise à jour de la configuration (`ossec.conf`) suivie d'un redémarrage du service, plutôt que de compter sur une réinstallation.
- Infrastructure détruite entre les sessions de travail (`tofu destroy`) pour maîtriser les coûts — implique de régénérer l'inventaire (`hosts.ini`) et le mot de passe admin Wazuh à chaque nouveau déploiement.

