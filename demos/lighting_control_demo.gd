# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name LightingControlDemo extends Control
## 


## The ColorRect to use
@export var color_rect: ColorRect


## IP address of node to connect to
var _ip_address: String = "192.168.1.255"

## Art-Net _port number
var _port: int = 6454

## Broadcast state
var _use_broadcast: bool = true

## Art-Net universe number
var _universe_number: int = 0

## Connection state
var _connection_state: bool = false

 ## PacketPeerUDP responsible for sending art-net packets
var _udp_peer = PacketPeerUDP.new()

## The color to animate
var _color: Color = Color.RED

## Animation speed
var _speed: float = 0.5


func _ready() -> void:
	Engine.max_fps = 40
	
	Network.get_local_node().is_now_session_master.connect(func ():
		set_output_state(true)
	)


func _process(delta: float) -> void:
	_color.h += delta * _speed
	color_rect.color = _color
	
	output({
		1: _color.r8,
		2: _color.g8,
		3: _color.b8,
	})


## Called when this output is started
func start():
	stop()
	_udp_peer.set_broadcast_enabled(_use_broadcast)
	var err: Error = _udp_peer.set_dest_address(_ip_address, _port)
	_connection_state = true

## Called when this output is stoped

func stop():
	output({})
	_udp_peer.close()
	_connection_state = false


## Called when this output it told to output
func output(dmx: Dictionary) -> void:
	if not _connection_state:
		return
	
	var packet = PackedByteArray([65, 114, 116, 45, 78, 101, 116, 0, 0, 80, 0, 14, 0, 0, int(_universe_number) % 256, int(_universe_number) / 256, 02, 00])
	
	for channel in range(1, 513):
		packet.append(clamp(dmx.get(channel, 0), 0, 255))
	
	# Send the packet
	_udp_peer.put_packet(packet)


func set_output_state(state: bool) -> void:
	if state:
		start()
	else:
		stop()
