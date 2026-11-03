#!/usr/bin/env bash
# Deploy the BrawlBits dedicated server to a Linux VM over ssh (idempotent: re-run to update).
#   server/deploy.sh user@host [port]      (default port 7777; the ssh user needs sudo, or be root)
# Run server/build.sh first (or the two godot exports) so build/server/ has the binaries.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${1:?usage: server/deploy.sh user@host [port]}"
PORT="${2:-7777}"

case "$(ssh "$HOST" uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "unsupported remote architecture" >&2; exit 1 ;;
esac
BIN="build/server/arena-server.$ARCH"
[[ -f "$BIN" ]] || { echo "missing $BIN: run server/build.sh first" >&2; exit 1; }
echo "deploying $BIN to $HOST (UDP $PORT)"

# The .pck is embedded in the binary. Upload under a temp name, then swap it in.
scp "$BIN" "$HOST:/tmp/arena-server.new"

# $PORT is expanded here, locally. `script` gives Godot a pty: it block-buffers stdout otherwise,
# and journalctl would stay empty.
ssh "$HOST" "sudo bash -s" <<EOF
set -euo pipefail
id brawlbits >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin brawlbits
install -d -o brawlbits /opt/brawlbits
install -m 755 /tmp/arena-server.new /opt/brawlbits/arena-server
rm -f /tmp/arena-server.new
cat > /etc/systemd/system/brawlbits.service <<UNIT
[Unit]
Description=BrawlBits dedicated server
After=network-online.target
Wants=network-online.target

[Service]
User=brawlbits
WorkingDirectory=/opt/brawlbits
ExecStart=/usr/bin/script -qefc "/opt/brawlbits/arena-server --headless -- --server --port $PORT --bots 0" /dev/null
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable brawlbits >/dev/null 2>&1
if command -v ufw >/dev/null; then ufw allow $PORT/udp; fi
systemctl restart brawlbits
sleep 2
systemctl --no-pager status brawlbits | head -n 12
journalctl -u brawlbits -n 15 --no-pager
EOF
echo "Done. In the app: Enter IP -> ${HOST#*@}:$PORT (and open UDP $PORT in the provider's firewall)."
