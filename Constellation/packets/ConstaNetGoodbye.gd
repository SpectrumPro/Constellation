# Copyright (c) Liam Sherwin. All rights reserved.
# This file is part of the Constellation Network Engine.
# Licensed under the GPL v3.0 or later. See the LICENSE.md file for details.

class_name ConstaNetGoodbye extends ConstaNetHeadder
## ConstaNET Goodbye packet, used to inform the network when a node is going offline


## init
func _init() -> void:
	type = Type.GOODBYE


## Gets this ConstaNetGoodbye as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {}


## Gets this ConstaNetGoodbye as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	return PackedByteArray()


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	pass


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	pass


## Checks if this ConstaNetGoodbye is valid
func _is_valid() -> bool:
	return true
