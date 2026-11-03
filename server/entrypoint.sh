#!/bin/sh
# Godot block-buffers stdout when it isn't a terminal (nothing reaches `docker logs` / journald),
# so run it under a pty with `script`. Extra args (e.g. --bots 2) are appended.
exec script -qefc "/opt/arena/arena-server --headless -- --server --port 7777 $*" /dev/null
