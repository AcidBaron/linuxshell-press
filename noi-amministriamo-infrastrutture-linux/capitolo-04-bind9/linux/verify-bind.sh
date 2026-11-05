#!/usr/bin/env bash
set -u

sudo named-checkconf
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone 0.77.10.in-addr.arpa /etc/bind/db.10.77.0

dig @10.77.0.10 fw01.lab.test A
dig @10.77.0.10 infra01.lab.test A
dig @10.77.0.10 linux-client01.lab.test A
dig @10.77.0.10 dns.lab.test CNAME
dig @10.77.0.10 -x 10.77.0.1
dig @10.77.0.10 -x 10.77.0.10
dig @10.77.0.10 -x 10.77.0.101
