# Genere un certificat auto-signe pour WinRM HTTPS
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My

# Active WinRM (config de base)
winrm quickconfig -quiet

# Supprime un eventuel listener HTTPS existant (idempotence)
Get-ChildItem WSMan:\Localhost\Listener | Where-Object { $_.Keys -contains "Transport=HTTPS" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# Cree le listener HTTPS via cmdlet natif (plus fiable que winrm create en ligne de commande)
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force

# Autorise l'authentification basique
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="false"}'

# Ouvre le port 5986 (idempotent : supprime la regle si elle existe deja)
Remove-NetFirewallRule -Name "WinRM-HTTPS" -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "WinRM over HTTPS" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

# Redemarre le service WinRM pour appliquer
Restart-Service WinRM