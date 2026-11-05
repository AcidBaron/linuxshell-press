# Capitolo 8 - verifica Windows verso files01
Resolve-DnsName files01.lab.test -DnsOnly
Test-NetConnection files01.lab.test -Port 445
Test-NetConnection files01.lab.test -Port 22
