# Copyright (c) 2026 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetHeartBeat extends ConstaNetHeadder
## ConstaNET HeartBeat packet


## Attribute Enum
enum Mode {
	UNKNOWN,		## Default State
	HEARTBEAT,		## Used as a ping 
	CONNECTION,		## Used to init a connection between nodes
	DISCONNECTION,	## Used to aggree if two notes can disconnect
}


## Byte length for the Mode
const L_MODE: TypeLength = TypeLength.UINT16

## Byte offset for the Mode
const O_MODE: int = 0

## String attribute for the Mode
const A_MODE: String = "mode"

## Message length
const MESSAGE_LENGTH: int = O_MODE + L_MODE


## Type of attribute
var mode: Mode = Mode.UNKNOWN


## Init
func _init() -> void:
	type = Type.HEARTBEAT


## Gets this ConstaNetSetAttribute as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_MODE: mode,
	}


## Gets this ConstaNetSetAttribute as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_LENGTH)
	
	result.encode_u16(O_MODE, mode)
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_mode = type_convert(p_dict.get(A_MODE, Mode.UNKNOWN), TYPE_INT)
	
	mode = p_mode


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_LENGTH:
		_network._log_warn("Unable to parse ConstaNetHeartBeat. Packet too short!")
		return
	
	var p_mode: int = p_packet.decode_u16(O_MODE)
	mode = p_mode as Mode


## Checks if this ConstaNetDiscovery is valid
func _is_valid() -> bool:
	if mode != Mode.UNKNOWN:
		return true
	
	return false
