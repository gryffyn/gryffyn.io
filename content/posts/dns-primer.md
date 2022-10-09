---
title: "A DNS Primer"
date: "2022-10-08"
description: "Setting the Scene"
draft: false
tags:
- dns
- infrastructure
- tutorial
series: ['Setting Up an Authoritative Nameserver with PowerDNS']
---

## Intro
{{< blockquote author="SSBroski" link="https://www.reddit.com/r/sysadmin/comments/4oj7pv/comment/d4czk91/" title="Reddit" >}}
It's not DNS  
There's no way it's DNS  
It was DNS  
{{< /blockquote >}}

DNS is complicated. This series of blogposts will hopefully help untangle the Knot, and get you out of your BIND. This series begins with a short primer on DNS records and server types, and then will cover setting up an authoritative DNS server with PowerDNS, setting up a web frontend using PowerDNS-Admin, anycast mirroring, and DNSSEC.

## DNS Records
```
www.example.com.      3600 IN A   10.20.30.40
```
This is an example of a DNS entry, known as an RRset (Resource Record set) in `BIND`-compatible format.

The first field, `www.example.com.`, is the name or locator for the DNS entry. This example indicates that this line is to be returned when the server is queried for the domain name `www.example.com`. The trailing dot is due to the fact that domain names are treated as labels separated by dots. The last trailing dot indicates that this is a fully qualified domain name, and not relative to any origin or other name. This field can contain relative names, such as `www`, if an origin is set above it in the zonefile -- such as `$ORIGIN example.com.`.

The second field, `3600`, is the TTL (Time To Live) interval of the record. It indicates how long the domain should be cached for before it is recursively resolved again.

The third field, `IN`, means Internet, as opposed to other networks in use at the time DNS was created. Some servers use this field for extra data -- both [coredns](https://coredns.io/plugins/chaos/) and [PowerDNS](https://doc.powerdns.com/authoritative/settings.html#version-string) use `CH` ([Chaosnet](https://en.wikipedia.org/wiki/Chaosnet)) records for version information. But likely you'll never see a record that's not `IN`, or at the very least won't have to fiddle with them.

The fourth field, `A`, is the type of query. There are a large number of query types in use in modern DNS servers, but the most common are `A` -- an IPv4 address, `AAAA` -- an IPv6 address, `TXT` -- a text record, `CNAME` -- a redirect to another domain, `MX` -- defines mail server lookups, and `NS` -- defines the nameservers used for the domain. Another query type, `SOA`, is not typically written by hand but created and updated by the DNS server. The `SOA` record, or Start of Authority, contains information about the zone itself. Examples of these query types can be found in [the next section](#bind-compatible-zonefiles).

The final field is the record data, also called Rdata. The Rdata type and length depends on the record type, but is typically limited to 255 bytes. 

### SOA Record Format
The `SOA` record is composed of 7 fields. The first field contains the primary nameserver for the zone, terminated with a dot. The second field contains the contact email address, formatted with a dot instead of an at (@) sign.

The serial field, the third field in the `SOA` record, contains the serial number for the zone. There are multiple ways the serial can be formatted, including a UNIX timestamp of the latest change, or initially set to `1` and incrememnted by 1 on each change, however the format recommended by [RFC 1912](https://www.rfc-editor.org/rfc/rfc1912) is `YYYYMMDDNN` where `NN` indicates the revision number. This starts at 01 and is incremented on each change to the zone by the primary nameserver. For zone transfers to occur, the serial number should be formatted correct and be the same on both the primary nameserver and the secondary nameserver(s). When the primary nameserver is updated, it is larger than the secondary nameserver's serial number, and when the secondary nameserver checks the `SOA` record on the primary afer the refresh timeout, it sees the serial has increased and initiates a zone transfer to update the zone on the secondary.

The next few fields set times for certain actions taken by the secondary nameserver(s). These times are typically in seconds, however newer versions of BIND and other DNS servers support using suffixes (such as s, m, d) to set times. The REFRESH time indicates in seconds how often the secondary namserver(s) query the `SOA` of the primary nameserver to check for changes. The RETRY field sets how long after an unsuccessful `SOA` query the secondary nameserver(s) may query the primary again. The EXPIRE field sets how long the secondaries should serve the zone after an unsuccessful query to the primary.

The MINIMUM field is a bit more confusing. This field, along with the `SOA` TTL value, determine the negative caching TTL for the zone. The authoritative nameserver uses the smaller of the two fields to determine the zone negative caching TTL. This field had historic uses which are [no longer applicable](https://www.rfc-editor.org/rfc/rfc2308#section-4).

### BIND-compatible zonefiles
Zonefiles are a common standard for representing entire DNS zones as plaintext.

Below is an example zonefile for the domain `example.com`.
```
$ORIGIN example.com.

; the @ sign at the start of a record indicates the root of the zone.
@        3600 IN SOA  ns1.example.com. hostmaster.example.com. (
                      2022100901 ; serial
                      43200      ; refresh (12 hours)
                      7200       ; retry (2 hours)
                      1209600    ; expire (2 weeks)
                      300        ; minimum (1 hour)
                      )

; This zone defines its own nameserver A records.
; If using hosted DNS, these are unnecessary.
ns1      3600 IN A    10.20.30.40
ns2      3600 IN A    11.21.31.41

; Every zone is required to have NS records
; pointing to the authoritative DNS namservers
; for the zone.
@        3600 IN NS   ns1.example.com.
@        3600 IN NS   ns2.example.com.

; Example A records. Starting a record with an
; unqualified domain name (such as the www below)
; are relative to the $ORIGIN.
; So www would become www.example.com.
www      3600 IN A    20.30.40.50
mail     3600 IN A    20.30.40.50

; MX records have two parts to the data --
; the first field indicates the priority for the server,
; and the second field is the address of the mail server.
@        3600 IN MX   10 mail.example.com.

; TXT record data should be contained in double quotes.
@        3600 IN TXT  "v=spf1 mx include:example.com ~all"

; Example AAAA (IPv6) record
@        3600 IN AAAA 2001:db8:dead:beef::1
```

## Resolver Types
(in no particular order)

### Stub
Stub resolvers are fairly simple. They are often found running on home routers, sometimes filtering out some requests and serving records for them, and then forwarding the rest of the traffic to a recursive resolver. These resolvers do not actual resolution of their own, past minor static hostname configuration or perhaps mDNS support. Instead they relay DNS lookups to another server or servers.

### Recursive
Recursive resolvers walk the DNS tree to resolve queries. As an example, let's say we've queried the IP address of the domain `www.example.com`. A recursive resolver will start with the 13 DNS root nameservers -- `a.root-servers.net` through `m.root-servers.net` -- and look up the domain in reverse order of the labels. It will query one of those 13 root nameservers for the authoritative resolver for `com`. It then queries that nameserver (or one of them) for the domain `example.com`. That domain's authoritative nameserver(s) are then queried for the A record at `www.example.com`. The resolver then returns that IP address. Typically, recursive resolvers maintain caches to minimize the number of queries they must do on frequently-resolved domains. Resolvers also may negatively cache domains, where if a queried domain does not exist (returns NXDOMAIN), the resolver caches the NXDOMAIN result.

Recursive resolvers do not serve any records themselves, but instead query records from authoritative servers.

Below is a recursive query for the domain `www.example.com`. DNSSEC is disabled because it clogs up the view and I haven't explained it yet.
```
$ dig +trace +nodnssec www.example.com.

; <<>> DiG 9.18.5 <<>> +trace +nodnssec www.example.com
;; global options: +cmd
.			82209	IN	NS	k.root-servers.net.
.			82209	IN	NS	a.root-servers.net.
.			82209	IN	NS	f.root-servers.net.
.			82209	IN	NS	b.root-servers.net.
.			82209	IN	NS	e.root-servers.net.
.			82209	IN	NS	m.root-servers.net.
.			82209	IN	NS	d.root-servers.net.
.			82209	IN	NS	g.root-servers.net.
.			82209	IN	NS	l.root-servers.net.
.			82209	IN	NS	j.root-servers.net.
.			82209	IN	NS	i.root-servers.net.
.			82209	IN	NS	h.root-servers.net.
.			82209	IN	NS	c.root-servers.net.
;; Received 239 bytes from 127.0.0.1#53(127.0.0.1) in 0 ms

com.			172800	IN	NS	g.gtld-servers.net.
com.			172800	IN	NS	e.gtld-servers.net.
com.			172800	IN	NS	c.gtld-servers.net.
com.			172800	IN	NS	b.gtld-servers.net.
com.			172800	IN	NS	k.gtld-servers.net.
com.			172800	IN	NS	m.gtld-servers.net.
com.			172800	IN	NS	a.gtld-servers.net.
com.			172800	IN	NS	d.gtld-servers.net.
com.			172800	IN	NS	j.gtld-servers.net.
com.			172800	IN	NS	f.gtld-servers.net.
com.			172800	IN	NS	h.gtld-servers.net.
com.			172800	IN	NS	i.gtld-servers.net.
com.			172800	IN	NS	l.gtld-servers.net.
;; Received 871 bytes from 192.33.4.12#53(c.root-servers.net) in 16 ms

example.com.		172800	IN	NS	a.iana-servers.net.
example.com.		172800	IN	NS	b.iana-servers.net.
;; Received 92 bytes from 192.48.79.30#53(j.gtld-servers.net) in 34 ms

www.example.com.	86400	IN	A	93.184.216.34
example.com.		86400	IN	NS	a.iana-servers.net.
example.com.		86400	IN	NS	b.iana-servers.net.
;; Received 108 bytes from 199.43.133.53#53(b.iana-servers.net) in 20 ms

```

As explained previously, `dig` starts with the root nameservers, and works down the address `www.example.com.` until it finds the authoritative resolver for that fully-qualified domain name, and returns the result.

### Authoritative
Authoritative resolvers, the type we'll be setting up today, serve authoritative records for the domains they are configured to serve. They do not recurse queries, and will typically answer `REFUSED` if queried for any domain outside of the set of domains it serves.

Below is an example of querying the A record for `example.com` directly from one of the authoritative nameservers that host that record.
```
$ dig +nodnssec @a.iana-servers.net. example.com.

; <<>> DiG 9.18.7 <<>> +nodnssec @a.iana-servers.net. example.com.
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 50695
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;example.com.			IN	A

;; ANSWER SECTION:
example.com.		86400	IN	A	93.184.216.34

;; Query time: 16 msec
;; SERVER: 199.43.135.53#53(a.iana-servers.net.) (UDP)
;; WHEN: Sun Oct 09 01:48:06 EDT 2022
;; MSG SIZE  rcvd: 56
```
