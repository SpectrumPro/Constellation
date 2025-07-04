#!/bin/bash

# Target broadcast address and port
BROADCAST_ADDR="255.255.255.255"
PORT="3823"

# Hex string (UTF-8 encoded JSON)
HEX_STRING="7b20226e6f64655f6e616d65223a20224e6f646541222c20226e6f64655f6970223a20223139322e3136382e312e3733222c202276657273696f6e223a20312c202274797065223a20312c2022666c616773223a20322c20226f726967696e5f6964223a202262393034646430652d323835372d343863632d383333622d613832666561306236663330222c20227461726765745f6964223a202222207d"

# Decode the hex to JSON
JSON_STRING=$(echo "$HEX_STRING" | xxd -r -p)

echo "Sending JSON: $JSON_STRING"

# Option 1: Using socat (preferred if installed)
if command -v socat >/dev/null 2>&1; then
    echo "$JSON_STRING" | socat - udp-datagram:"$BROADCAST_ADDR":$PORT,broadcast
    exit 0
fi

# Option 2: Using netcat (nc)
if command -v nc >/dev/null 2>&1; then
    echo "$JSON_STRING" | nc -u -b "$BROADCAST_ADDR" "$PORT"
    exit 0
fi

echo "Error: Neither socat nor nc (netcat) is installed." >&2
exit 1

