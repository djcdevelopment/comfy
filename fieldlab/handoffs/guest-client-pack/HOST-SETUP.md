# Host runbook — invite a guest onto the P7 cutover server

Host-side companion to [README.md](README.md) (the guest's install guide). This is what the host
(Derek) does to bring the GCP P7 server up and put the guest's join **through the Lumberjacks
cutover**. Everything here is repeatable; the guest's only inputs are their own Valheim/Steam, the
join password, and the server IP.

Topology: `OMEN + guest (vanilla Valheim + ComfyNetworkSense) --UDP 2456--> GCP Valheim server
(BepInEx + mod, handshake-armed) --HTTP--> Lumberjacks gateway (admission decision)`. The mod is
**server-side** for admission; clients just join by IP.

## 1. Bring the server up (idle VMs are stopped for cost)

```bash
gcloud compute instances start comfy-lumberjacks-p7 --zone us-west1-b
```

The `comfy-lumberjacks-p7.service` systemd unit starts the whole compose stack (~20 s); the world
finishes loading ~30 s later. Verify (health is public; SSH is IAP, run **foreground**):

```bash
curl -s http://8.231.129.249:4000/health                       # {"status":"ok",...}
gcloud compute ssh comfy-lumberjacks-p7 --zone us-west1-b --tunnel-through-iap \
  --command='sudo docker ps --format "{{.Names}}\t{{.Status}}"'
```

Firewall of record: `udp:2456-2457` open to `0.0.0.0/0` (join), `tcp:4000` pinned to the host's
public IP (gateway/harness). If the host's ISP IP rotated, update
`comfy-lumberjacks-p7-lumberjacks-control` or the client-side path fails.

## 2. Arm the cutover (continuous handshake, accept-all)

Server cfg lives at the bepinex **root**: `/mnt/comfy-p7/valheim/config/bepinex/djcdevelopment.valheim.comfynetworksense.cfg`.

```bash
gcloud compute ssh comfy-lumberjacks-p7 --zone us-west1-b --tunnel-through-iap --command='
CFG=/mnt/comfy-p7/valheim/config/bepinex/djcdevelopment.valheim.comfynetworksense.cfg
sudo sed -i \
 -e "s/^handshakeResponderEnabled = .*/handshakeResponderEnabled = true/" \
 -e "s/^handshakeResponderWindowId = .*/handshakeResponderWindowId = guest-demo-w1/" \
 -e "s/^handshakeResponderActiveSeconds = .*/handshakeResponderActiveSeconds = 0/" \
 -e "s/^netcodeProbeAutoStartEnabled = .*/netcodeProbeAutoStartEnabled = false/" "$CFG"
sudo docker exec comfy-lumberjacks-p7-valheim-server-1 /usr/local/bin/supervisorctl restart valheim-server'
```

`activeSeconds = 0` = continuous (the responder self-arms on server start and stays armed for the
session). Keep `zdoRedirectEnabled` / `zdoInjectionEnabled` / `ownershipPinEnabled` **false** — a
free-roam guest session only wants the handshake decision, not the measurement windows (redirect
suppresses tagged-tree sync). Wait for the server log line
`[ComfyNetworkSense][handshake] ARMED window=guest-demo-w1 ... continuous`.

Configure the gateway window for accept-all (any Steam client with the join password; vanilla still
enforces the real password on the accept path):

```bash
B=http://8.231.129.249:4000; W=guest-demo-w1
curl -s -X POST "$B/valheim/handshake/reset/$W"
curl -s -X POST "$B/valheim/handshake/config" -H 'Content-Type: application/json' \
  -d "{\"window_id\":\"$W\",\"context\":{\"permitted_hosts\":[],\"banned_hosts\":[]}}"
curl -s "$B/valheim/handshake/status/$W"    # want permitted_hosts:0, need_password:false
```

To whitelist instead of accept-all, put SteamID64s in `permitted_hosts` (host is
`76561198088711642`).

## 3. Point the host client (OMEN)

- Mod **0.5.19** must be installed (`...\Valheim\BepInEx\plugins\ComfyNetworkSense.dll`) — same DLL
  as the guest pack.
- Auto-teleport-on-login is off (`autoRehearsalEnabled`, `coupleAutoRehearsalToNetcodeProbe`,
  `netcodeProbeAutoStartEnabled` = false). Relaunch Valheim (don't menu-rejoin) so the new DLL/cfg
  load, then **Join Game → Join by IP → `8.231.129.249:2456`** + password.
- Fly: F5 console → `network_sense_godfly on` (jump up, crouch down), `network_sense_godfly off` to
  land. Works around the client cheat-gate on a dedicated server.

## 4. Send the guest

Send them `ComfyNetworkSense-guest-pack.zip` (DLL + [README.md](README.md)), the join password, and
`8.231.129.249:2456`. They need their own licensed Valheim on a **separate** Steam account.

## 5. Watch it work / tear down

```bash
curl -s http://8.231.129.249:4000/valheim/handshake/status/guest-demo-w1   # accepted count ticks per join
```

When done, disarm back to observe-only and stop the VM to end billing:

```bash
gcloud compute ssh comfy-lumberjacks-p7 --zone us-west1-b --tunnel-through-iap --command='
CFG=/mnt/comfy-p7/valheim/config/bepinex/djcdevelopment.valheim.comfynetworksense.cfg
sudo sed -i "s/^handshakeResponderEnabled = .*/handshakeResponderEnabled = false/" "$CFG"
sudo docker exec comfy-lumberjacks-p7-valheim-server-1 /usr/local/bin/supervisorctl restart valheim-server'
gcloud compute instances stop comfy-lumberjacks-p7 --zone us-west1-b
```
