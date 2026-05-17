# Copyright (c) 2026 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetHeartBeat extends ConstaNetHeadder
## ConstaNET HeartBeat packet


## Attribute Enum
enum Mode {
	UNKNOWN,		## Default State
	HEARTBEAT,		## Used as a ping 
	CONNECTION,		## Used to init a connection between nodes
}


## Type of attribute
var mode: Mode = Mode.UNKNOWN


## Init
func _init() -> void:
	type = Type.HEARTBEAT


## Gets this ConstaNetSetAttribute as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		"mode": mode,
	}


## Gets this ConstaNetSetAttribute as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	
	result.append_array(ba(mode, 2))
	
	return result


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	mode = type_convert(p_dict.get("mode", Mode.UNKNOWN), TYPE_INT)


## Phrases a PackedByteArray
func _phrase_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < 2:
		return
	
	var offset: int = 0
	
	mode = ba_to_int(p_packet, offset, 2) as Mode
	offset += 2


## Checks if this ConstaNetDiscovery is valid
func _is_valid() -> bool:
	if mode != Mode.UNKNOWN:
		return true
	
	return false
