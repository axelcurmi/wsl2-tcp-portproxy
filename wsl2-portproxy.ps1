# Settings
$firewall_rule_name = "WSL2 Firewall";
$ports = @("80", "8000", "8080", "4240-4249");

$wsl_ip = bash.exe -c "ip addr show eth0 | grep 'inet\b' | xargs | cut -d' ' -f2 | cut -d'/' -f1";

function DeletePortProxy {
    param (
        $ListenAddress,
        $ListenPort
    )

    netsh interface portproxy delete v4tov4 listenaddress=$ListenAddress listenport=$ListenPort;
}

function AddPortProxy {
    param (
        $ListenAddress,
        $ConnectAddress,
        $ListenAndConnectPort
    )

    netsh interface portproxy add v4tov4 listenaddress=$ListenAddress listenport=$ListenAndConnectPort connectaddress=$ConnectAddress connectport=$ListenAndConnectPort;
}

# Remove Firewall Exception Rules
try {
    Remove-NetFireWallRule -DisplayName $firewall_rule_name -ErrorAction Stop;
} catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
    Write-Warning "Skipping removal of firewall rule as no rule exists with name '$firewall_rule_name'";
} catch {
    Write-Warning $_;
    exit 1;
}

# Add Firewall Rules
New-NetFireWallRule -DisplayName $firewall_rule_name -Direction Outbound -LocalPort $ports -Action Allow -Protocol TCP;
New-NetFireWallRule -DisplayName $firewall_rule_name -Direction Inbound  -LocalPort $ports -Action Allow -Protocol TCP;

foreach ($port in $ports) {
    if ($port.Contains("-")) {
        $port_mapping = $port.Split("-");
        $from = [int]$port_mapping[0];
        $to = [int]$port_mapping[1];

        for ($i = $from; $i -le $to; $i++) {
            DeletePortProxy -ListenAddress "*" -ListenPort $i;
            AddPortProxy -ListenAddress "*" -ConnectAddress $wsl_ip -ListenAndConnectPort $i;
        }
    } else {
        DeletePortProxy -ListenAddress "*" -ListenPort $port;
        AddPortProxy -ListenAddress "*" -ConnectAddress $wsl_ip -ListenAndConnectPort $port;
    }
}
