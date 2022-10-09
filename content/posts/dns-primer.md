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

The third field, `A`, is the type of query. There are a large number of query types in use in modern DNS servers, but the most common are `A` -- an IPv4 address, `AAAA` -- an IPv6 address, `TXT` -- a text record, `CNAME` -- a redirect to another domain, `MX` -- defines mail server lookups, and `NS` -- defines the nameservers used for the domain.

The final field is the record data, also called Rdata. The Rdata type and length depends on the record type, but is typically limited to 255 bytes. 

## Resolver Types
(in no particular order)

### Stub
Stub resolvers are fairly simple. They are often found running on home routers, sometimes filtering out some requests and serving records for them, and then forwarding the rest of the traffic to a recursive resolver. These resolvers do not actual resolution of their own, past minor static hostname configuration or perhaps mDNS support. Instead they relay DNS lookups to another server or servers.

### Recursive
Recursive resolvers walk the DNS tree to resolve queries. As an example, let's say we've queried the IP address of the domain `www.example.com`. A recursive resolver will start with the 13 DNS root nameservers -- `a.root-servers.net` through `m.root-servers.net` -- and look up the domain in reverse order of the labels. It will query one of those 13 root nameservers for the authoritative resolver for `com`. It then queries that nameserver (or one of them) for the domain `example.com`. That domain's authoritative nameserver(s) are then queried for the A record at `www.example.com`. The resolver then returns that IP address. Typically, recursive resolvers maintain caches to minimize the number of queries they must do on frequently-resolved domains.

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
