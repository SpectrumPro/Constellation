# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetHeadder extends RefCounted
## Base ConstsNetHeadder class for ConstaNET headders


## Current proto version
const VERSION: int = 1

## Type Enum
enum Type {
	UNKNOWN, 			# Init base state
	
	DISCOVERY,			# Client/server broadcasts "Who’s there?"
	COMMAND,			# Lighting cue or control command
	
	SET_ATTRIBUTE,		# Sets an attribute on a node, name, ipaddress, ect..
	STATE_REQUEST,		# Request full state sync
	HEARTBEAT,			# Periodic alive signal
	
	PRIORITY_SET,		# Set failover priority
	PRIORITY_GET,		# Get failover priority
	
	SESSION_ANOUNCE,	# Creates a new session
	SESSION_JOIN,		# New node joining a session
	SESSION_LEAVE,		# Node leaving a session
	
	SYS_EXCLUSIVE		# Device/vendor specific or extended data
}


## Flags Enum (bitmask-compatible)
enum Flags {
	NONE				= 0,
	REQUEST				= 1 << 0,
	ACKNOWLEDGMENT		= 1 << 1,
	ERROR				= 1 << 2
}


## Matches the Type enum to a class
static var ClassTypes: Dictionary[int, Script] = {
	Type.UNKNOWN: ConstaNetHeadder,
	Type.DISCOVERY: ConstaNetDiscovery,
	Type.SET_ATTRIBUTE: ConstaNetSetAttribute
}


## The type of this ConstaNET packet
var type: Type = Type.UNKNOWN

## Flags for this ConstaNET packet
var flags: Flags = Flags.NONE

## The UUID for the origin node 
var origin_id: String = ""

## The UUID for the target node
var target_id: String

## Version number of the orignal message
var _origin_version: int = 0


## Gets this ConstaNETHeadder as a Dictionary
func get_as_dict() -> Dictionary[String, Variant]:
	return _get_as_dict().merged({
		"version": VERSION,
		"type": type,
		"flags": flags,
		"origin_id": origin_id,
		"target_id": target_id
	})


## Gets this ConstaNETHeadder as a String
func get_as_string() -> String:
	return str(get_as_dict())


## Returns true if this ConstaNet message is valid
func is_valid() -> bool:
	if not type or not origin_id or _origin_version != VERSION:
		return false
	
	return _is_valid()


## Phrases a Dictionary
static func phrase_dict(p_dict: Dictionary) -> ConstaNetHeadder:
	var message: ConstaNetHeadder
	
	var p_origin_version: int = type_convert(p_dict.get("version", 0), TYPE_INT)
	var p_type: int = type_convert(p_dict.get("type", 0), TYPE_INT)
	var p_flags: int = type_convert(p_dict.get("flags", 0), TYPE_INT)
	var p_origin_id: String = type_convert(p_dict.get("origin_id", ""), TYPE_STRING)
	var p_target_id: String = type_convert(p_dict.get("target_id", ""), TYPE_STRING)
	
	if p_type not in ClassTypes:
		return null
	
	message = ClassTypes[p_type].new()
	message._origin_version = p_origin_version
	message.type = p_type
	message.flags = p_flags
	message.origin_id = p_origin_id
	message.target_id = p_target_id
	
	message._phrase_dict(p_dict)
	
	return message


## Phrases a String
static func phrase_string(p_string: String) -> ConstaNetHeadder:
	var data: Dictionary = JSON.parse_string(p_string)
	return phrase_dict(data)


## Override this function to provide a method to get the packet as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {}


## Override this function to provide a method to phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	pass


## Override this function to provide a method to check if its a valid message
func _is_valid() -> bool:
	return false
