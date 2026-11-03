# Play over the internet

1. **Get a VM.** Any cheap Ubuntu/Debian box with a public IP and ssh access (about $5/month: Hetzner, DigitalOcean, Vultr, Lightsail...). x86_64 or arm64 both work. Note its IP.
2. **Open UDP 7777** in the provider's firewall / security group (the game uses UDP only; `deploy.sh` also opens it in ufw if the VM has ufw).
3. **Build and deploy** from this repo (needs Godot 4.7.2 with export templates, and Docker only for the optional image):
   ```
   server/build.sh                       # exports build/server/arena-server.{amd64,arm64} (+ local Docker image)
   server/deploy.sh root@<vm-ip>         # or user@host with sudo; optional 2nd arg = port (default 7777)
   ```
   This installs `/opt/brawlbits/arena-server` and a `brawlbits` systemd service (`Restart=always`, starts on boot, no bots). Re-run it to update the binary. Logs: `ssh root@<vm-ip> journalctl -u brawlbits -f` (start line with port + protocol version, a line per join/leave and per match event).
4. **Play.** In the app: main menu, Enter IP, type `<vm-ip>:7777`, join.

**Version caveat:** client and server must be the same build (`LanDiscovery.VERSION` and the net protocol). After any protocol change, rebuild and re-run `server/deploy.sh`, and ship a matching client.

Extra server flags (`--mode duel|ffa|teams`, `--arena N`, `--bots N`, `--time-limit S`): edit the `ExecStart` line in `deploy.sh` and re-run it.

Docker instead of systemd: `docker run -d --restart always -p 7777:7777/udp arena-brawler-server --bots 0` (`PLATFORM=linux/amd64 server/build.sh` for an x86 VM).

Note: Godot buffers stdout when it is not a terminal, so both the Docker entrypoint and the systemd unit run it under `script` (a pty); without that, `journalctl` / `docker logs` stay empty.
