#!/usr/bin/env python3
"""Check lab JSONs, inventories, port maps, Netplan fragments and relative assets."""
import csv
import ipaddress
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def check(count):
    path = ROOT / 'labs' / f'{count}node'
    t = json.loads((path / 'topology.json').read_text())
    inventory = json.loads((path / 'inventory.json').read_text())
    nodes = t['content']['nodes']
    expected = {f'WekaNode{i:02}' for i in range(1, count + 1)} | {'Client01', 'Client02', 'SN5600-1'}
    assert set(nodes) == expected, 'Unexpected node inventory'
    assert inventory['backend_count'] == count
    assert (path / f'storage.{count}').read_text().splitlines() == [f'10.200.100.{10+i}' for i in range(1, count+1)]
    assert t['ztp'] is None and t['content']['oob'] is True
    ips, macs, endpoints = [], [], []
    for name, n in nodes.items():
        for interface, m in n['management_interfaces'].items():
            ips.append(str(ipaddress.IPv4Address(m['ip'])))
            macs.append(m['mac_address'].lower())
            endpoints.append((name, interface))
        if name.startswith('Weka'):
            assert (n['cpu'], n['memory'], n['storage']) == (6, 24576, 32)
            assert n['cpu_mode'] == 'host-passthrough'
            assert [d['size'] for d in n['storage_pci'].values()] == [48, 8]
    connections = set()
    for link in t['content']['links']:
        assert len(link) == 2
        for e in link:
            if e == 'unconnected':
                continue
            assert e['node'] in nodes
            endpoints.append((e['node'], e['interface']))
            macs.append(e['mac'].lower())
        if all(isinstance(e, dict) for e in link):
            sw = next(e for e in link if e['node'] == 'SN5600-1')
            h = next(e for e in link if e['node'] != 'SN5600-1')
            connections.add((h['node'], h['interface'], sw['node'], sw['interface']))
    assert len(ips) == len(set(ips)), 'Duplicate management IP'
    assert len(macs) == len(set(macs)), 'Duplicate MAC'
    assert len(endpoints) == len(set(endpoints)), 'Duplicate endpoint'
    assert len(connections) == count + 2
    with (path / 'port-map.csv').open() as f:
        rows = list(csv.DictReader(f))
    assert connections == {(a['host'], a['host_interface'], a['switch'], a['switch_interface']) for a in rows}
    hosts = inventory['hosts']
    assert len(hosts) == count + 2 and {h['name'] for h in hosts} == expected - {'SN5600-1'}
    data_ips = set()
    for h in hosts:
        assert h['management_ip'] == nodes[h['name']]['management_interfaces']['eth0']['ip']
        ipaddress.IPv4Address(h['data_ip'])
        assert h['data_ip'] not in data_ips
        data_ips.add(h['data_ip'])
        y = (path / 'config' / 'netplan' / f"{h['name']}.yaml").read_text()
        assert f"{h['data_ip']}/24" in y and 'mtu: 9000' in y and 'eth0:' not in y
    print(f'{count}node: node, IP/MAC, links, port map, inventory and network fragments OK')

def main():
    for n in (8,):
        check(n)
    for md in ROOT.rglob('*.md'):
        for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', md.read_text()):
            if target.startswith(('http:', 'https:', '#', 'mailto:')):
                continue
            assert (md.parent / target.split('#', 1)[0]).exists(), f'Broken link: {md}: {target}'
    for svg in ROOT.rglob('*.svg'):
        ET.parse(svg)
    print('Relative Markdown links and SVG syntax OK')

if __name__ == '__main__':
    try:
        main()
    except (AssertionError, OSError, ValueError, KeyError, StopIteration) as exc:
        print(f'FAIL: {exc}', file=sys.stderr)
        sys.exit(1)
