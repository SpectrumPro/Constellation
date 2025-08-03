#!/usr/bin/bash

killall RelayServer

godot --headless --main-loop RelayServer
