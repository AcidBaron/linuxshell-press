# Noi Amministriamo Infrastrutture Linux

Materiale operativo associato al libro **Noi Amministriamo Infrastrutture Linux** — Linuxshell Press.

Il libro resta la fonte editoriale e didattica autorevole. Questo albero raccoglie i file operativi usati nei laboratori: configurazioni finali, comandi, script, verifiche e rollback.

## Organizzazione

- [Capitolo 1 – Laboratorio di riferimento con Windows 11 e Hyper-V](./capitolo-01-hyper-v/)
- [Capitolo 2 – Costruire un router/firewall Linux](./capitolo-02-router-firewall/)
- [Capitolo 3 – Progettare la rete del laboratorio](./capitolo-03-progetto-rete/)
- [Capitolo 4 – DNS con BIND9](./capitolo-04-bind9/)
- [Laboratorio parallelo – DHCP con Kea e ISC DHCP legacy](./laboratorio-dhcp-kea-isc/)
- [Capitolo 5 – VLAN, segmentazione e reti multiple](./capitolo-05-vlan-segmentazione/)
- [Capitolo 6 – IPv6 nell'infrastruttura moderna](./capitolo-06-ipv6/)
- [Capitolo 7 – Reti miste Linux e Windows](./capitolo-07-reti-miste/)
- [Capitolo 8 – Samba](./capitolo-08-samba/)
- [Capitolo 9 – Proxy forward con Squid](./capitolo-09-squid/)
- [Capitolo 10 – Reverse proxy con Nginx e HAProxy](./capitolo-10-reverse-proxy/)
- [Capitolo 11 – Proxy, TLS, certificati e pubblicazione dei servizi](./capitolo-11-tls-certificati/)
- [Capitolo 12 – VPN con WireGuard e OpenVPN](./capitolo-12-vpn/)
- [Capitolo 13 – Directory e identità centralizzate](./capitolo-13-identita-centralizzate/)
- [Capitolo 14 – LDAP e OpenLDAP: una directory essenziale](./capitolo-14-ldap-openldap/)
- [Capitolo 15 – FreeIPA e Identity Management: identità, Kerberos e policy integrate](./capitolo-15-freeipa-idm/)
- [Capitolo 16 – Active Directory e integrazione Linux](./capitolo-16-active-directory/)
- [Capitolo 17 – SSSD, realmd e Kerberos](./capitolo-17-sssd-realmd-kerberos/)
- [Capitolo 18 – Trust fra domini Linux e Active Directory](./capitolo-18-trust-linux-active-directory/)
- [Capitolo 19 – PKI e gestione dei certificati](./capitolo-19-pki-certificati/)
- [Laboratorio parallelo – pfSense](./laboratorio-pfsense/)
- [Laboratorio parallelo – Provisioning automatico di VM Linux da golden image](./laboratorio-provisioning-golden-image/)

## Convenzioni

- `config/`: file di configurazione finali o varianti esplicitamente indicate.
- `powershell/`: comandi e script lato Hyper-V/Windows.
- `linux/`: verifiche e procedure lato Linux.
- `legacy/`: equivalenti legacy, esercizi di migrazione o materiale storico.
- `rollback/`: procedure di ritorno allo stato precedente quando utili.

Le procedure diagnostiche non vengono presentate come configurazioni finali. Il testo del libro resta l'autorità per spiegazioni, prerequisiti, rischi e sequenza didattica.
