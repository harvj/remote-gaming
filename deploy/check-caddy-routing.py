#!/usr/bin/env python3
"""Verify host priority and upstreams in an adapted Caddy candidate."""
import json
import sys

config = json.load(sys.stdin)
servers = config["apps"]["http"]["servers"].values()
routes = [
    route
    for server in servers
    for route in server.get("routes", [])
    if any("host" in matcher for matcher in route.get("match", []))
]


def upstreams(node):
    if isinstance(node, dict):
        if node.get("handler") == "reverse_proxy":
            yield from (upstream["dial"] for upstream in node["upstreams"])
        for value in node.values():
            yield from upstreams(value)
    elif isinstance(node, list):
        for value in node:
            yield from upstreams(value)


def route_for(host):
    for route in routes:
        for matcher in route.get("match", []):
            for pattern in matcher.get("host", []):
                wildcard = pattern.startswith("*.") and host.partition(".")[2] == pattern[2:]
                if pattern == host or wildcard:
                    return route
    return {}


expected = {
    "arkham.radioactivita.com": ["unix//var/www/arkham/shared/tmp/sockets/puma.sock"],
    **dict.fromkeys(
        ("radioactivita.com", "gaming.harvj.com", "pandemic.radioactivita.com", "modernart.radioactivita.com"),
        ["127.0.0.1:3012"],
    ),
}
if "--wildcard" in sys.argv:
    expected["p10-unregistered.radioactivita.com"] = ["127.0.0.1:3012"]
if "--staging" in sys.argv:
    staging_hosts = {"staging.radioactivita.com", "modern-art.staging.radioactivita.com", "pandemic.staging.radioactivita.com"}
    for staging in staging_hosts:
        expected[staging] = ["127.0.0.1:3013"]
        route = route_for(staging)
        exact = any(set(matcher.get("host", [])) == staging_hosts for matcher in route.get("match", []))
        guarded = any(
            candidate.get("match") is None
            and [handler.get("handler") for handler in candidate["handle"]][-2:] == ["authentication", "reverse_proxy"]
            for outer in route.get("handle", [])
            for candidate in outer.get("routes", [])
        )
        if not (exact and guarded):
            raise SystemExit(f"{staging} must use a named hostname and require edge authentication before proxying")
    print("Private staging Caddy route verified")
for host, upstream in expected.items():
    actual = list(upstreams(route_for(host)))
    if actual != upstream:
        raise SystemExit(f"{host}: expected {upstream}, got {actual}")
print("Remote Gaming and Arkham Caddy routes verified")
