
# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetDiscovery extends ConstaNetHeadder
## ConstaNET Discovery packet


## The name of the origin node
var node_name: String = "UnNamedNode"

## The IP address of the origin node
var node_ip: String = ""


## Init
func _init() -> void:
	type = Type.DISCOVERY


## Gets this ConstaNetDiscovery as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		"node_name": node_name,
		"node_ip": node_ip
	}


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	node_name = type_convert(p_dict.get("node_name", ""), TYPE_STRING)
	node_ip = type_convert(p_dict.get("node_ip", ""), TYPE_STRING)


## Checks if this ConstaNetDiscovery is valid
func _is_valid() -> bool:
	if node_name and node_ip:
		return true
	
	return false
