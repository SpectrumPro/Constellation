# Copyright (c) 2026 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetHeadder extends RefCounted
## Base ConstsNetHeadder class for ConstaNET headders


## Type Enum
enum Type {
	UNKNOWN, 				# Init base state
	
	DISCOVERY,				# Client/server broadcasts "Who’s there?"
	GOODBYE,				# Node going offline
	COMMAND,				# Lighting cue or control command
	MULTI_PART,				# Multipart messsage
	
	SET_ATTRIBUTE,			# Sets an attribute on a node, name, ipaddress, ect..
	STATE_REQUEST,			# Request full state sync
	HEARTBEAT,				# Periodic alive signal
	
	SESSION_DISCOVERY,		# Announcement / discovery request for a session
	SESSION_SET_ATTRIBUTE,	# Sets an attribute on a session, name, master, ect..
	SESSION_SET_PRIORITY,	# Sets the fail over proirity of a node
	
	SYS_EXCLUSIVE			# Device/vendor specific or extended data
}

## Flags Enum (bitmask-compatible)
enum Flags {
	NONE				= 0,		# Default state
	REQUEST				= 1 << 0,	# This message is requesting a responce
	ACKNOWLEDGMENT		= 1 << 1,	# This message is responding to a request
	ERROR				= 1 << 2,	# This message contains an error
	ANNOUNCEMENT		= 1 << 3,	# This message contains new or updated infomation
	DENIED				= 1 << 4,	# This action has been denied by the sender, used with ACKNOWLEDGMENT
	ALLOWED				= 1 << 5,	# This action has been allowed by the sender, used with ACKNOWLEDGMENT
}

## Enum for network roles
enum RoleFlags {
	NONE				= 0,
	EXECUTOR			= 1 << 0,	# Performs the actions defined by the Controller
	CONTROLLER			= 1 << 1,	# # Sends control and command messages to the Executer 
}

## Enum for data type lengths
enum TypeLength {
	UINT8		= 1,
	INT8		= 1,
	BOOL		= 1,
	
	UINT16		= 2,
	INT16		= 2,
	
	UINT32		= 4,
	INT32		= 4,
	FLOAT32		= 4,
	
	UINT64		= 8,
	INT64		= 8,
	FLOAT64		= 8,
	
	NODEID		= 36,
	BLOCK		= 0,
	IPV4		= 4,
}

## Matches the Type enum to a class
static var ClassTypes: Dictionary[int, Script] = {
	Type.UNKNOWN: 				ConstaNetHeadder,
	
	Type.DISCOVERY: 			ConstaNetDiscovery,
	Type.GOODBYE: 				ConstaNetGoodbye,
	Type.COMMAND: 				ConstaNetCommand,
	Type.MULTI_PART: 			ConstaNetMultiPart,
	
	Type.SET_ATTRIBUTE: 		ConstaNetSetAttribute,
	Type.HEARTBEAT:				ConstaNetHeartBeat,
	
	Type.SESSION_DISCOVERY: 	ConstaNetSessionDiscovery,
	Type.SESSION_SET_ATTRIBUTE: ConstaNetSessionSetAttribute,
	Type.SESSION_SET_PRIORITY: 	ConstaNetSessionSetPriority,
}


## Byte length for VERSION number
const L_PROTO_VERSION: TypeLength = TypeLength.UINT16

## Byte length for message size
const L_MSG_SIZE: TypeLength = TypeLength.UINT64

## Byte length for message type
const L_MSG_TYPE: TypeLength = TypeLength.UINT16

## Byte length for message flags
const L_MSG_FLAGS: TypeLength = TypeLength.UINT16


## Byte offset for VERSION number
const O_PROTO_VERSION: int = 0

## Byte offset for message size
const O_MSG_SIZE: int = O_PROTO_VERSION + L_PROTO_VERSION

## Byte offset for message type
const O_MSG_TYPE: int = O_MSG_SIZE + L_MSG_SIZE

## Byte offset for message flags
const O_MSG_FLAGS: int = O_MSG_TYPE + L_MSG_TYPE


## String attribute for protocal version
const A_PROTO_VERSION: String = "version"

## String attribute for message type
const A_MSG_TYPE: String = "type"

## String attribute for message flags
const A_MSG_FLAGS: String = "flags"

## String attribute for message origin NodeID
const A_MSG_ORIGIN: String = "origin_id"

## String attribute for message target NodeID
const A_MSG_TARGET: String = "target_id"


## Current proto version as uint16
const VERSION: int = 7

## Byte length for a NodeID
const NODE_ID_LENGTH: int = TypeLength.NODEID

## Length of a ConstaNetHeadder, without origin and target NodeIDs
const HEADDER_LENGTH_NO_ID: int = O_MSG_FLAGS + L_MSG_FLAGS

## Length of a ConstaNetHeadder
const HEADDER_LENGTH: int = HEADDER_LENGTH_NO_ID + NODE_ID_LENGTH + NODE_ID_LENGTH

## Length of a IPv4 Address
const IPV4_LENGTH: int = TypeLength.IPV4


## The type of this ConstaNET packet
var type: Type = Type.UNKNOWN

## Flags for this ConstaNET packet
var flags: int = Flags.NONE

## The UUID for the origin node 
var origin_id: String = ""

## The UUID for the target node
var target_id: String

## Version number of the orignal message
var _origin_version: int = 0

## The Constellation CoreGlobal instance
static var _network: Constellation


## Gets this ConstaNETHeadder as a Dictionary
func get_as_dict() -> Dictionary[String, Variant]:
	return _get_as_dict().merged({
		A_PROTO_VERSION: VERSION,
		A_MSG_TYPE: type,
		A_MSG_FLAGS: flags,
		A_MSG_ORIGIN: origin_id,
		A_MSG_TARGET: target_id
	})


## Gets this ConstaNETHeadder as a String
func get_as_string() -> String:
	return str(get_as_dict())


## Gets this ConstaNetHeadder as a PackedByteArray
func get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	
	result.resize(HEADDER_LENGTH_NO_ID)
	
	result.encode_u16(O_PROTO_VERSION, VERSION)		## Version number
	result.encode_u64(O_MSG_SIZE, 0)				## Placeholder size
	result.encode_u16(O_MSG_TYPE, type)				## Meassage type
	result.encode_u16(O_MSG_FLAGS, flags)			## Messsage flags
	
	result.append_array(get_origin_as_buffer())		## OriginID
	result.append_array(get_target_as_buffer())		## TargetID
	
	result.append_array(_get_as_packet())			## Meassage body
	result.encode_u64(O_MSG_SIZE, result.size())	## Meassage length
	
	return result


## Returns the origin of this message as a PackedByteArray with length of NODE_ID_LENGTH
func get_origin_as_buffer() -> PackedByteArray:
	return get_id_as_buffer(origin_id)


## Returns the target of this message as a PackedByteArray with length of NODE_ID_LENGTH
func get_target_as_buffer() -> PackedByteArray:
	return get_id_as_buffer(target_id)


## Returns true if this ConstaNet message is valid
func is_valid() -> bool:
	if not type or not origin_id or _origin_version != VERSION:
		return false
	
	return _is_valid()


## Sets this ConstaNet message's Request flag
func set_request(p_state: bool) -> void:
	if p_state:
		flags |= Flags.REQUEST
	else:
		flags &= ~Flags.REQUEST


## Sets this ConstaNet message's Acknowledgment flag
func set_acknowledgment(p_state: bool) -> void:
	if p_state:
		flags |= Flags.ACKNOWLEDGMENT
	else:
		flags &= ~Flags.ACKNOWLEDGMENT


## Sets this ConstaNet message's Error flag
func set_error(p_state: bool) -> void:
	if p_state:
		flags |= Flags.ERROR
	else:
		flags &= ~Flags.ERROR


## Sets this ConstaNet message's Announcement flag
func set_announcement(p_state: bool) -> void:
	if p_state:
		flags |= Flags.ANNOUNCEMENT
	else:
		flags &= ~Flags.ANNOUNCEMENT


## Sets this ConstaNet message's Denied flag
func set_denied(p_state: bool) -> void:
	if p_state:
		flags |= Flags.DENIED
	else:
		flags &= ~Flags.DENIED


## Sets this ConstaNet message's Allowed flag
func set_allowed(p_state: bool) -> void:
	if p_state:
		flags |= Flags.ALLOWED
	else:
		flags &= ~Flags.ALLOWED


## Returns true if the Request flag is set
func is_request() -> bool:
	return (flags & Flags.REQUEST) != 0


## Returns true if the Acknowledgment flag is set
func is_acknowledgment() -> bool:
	return (flags & Flags.ACKNOWLEDGMENT) != 0


## Returns true if the Error flag is set
func is_error() -> bool:
	return (flags & Flags.ERROR) != 0


## Returns true if the Announcement flag is set
func is_announcement() -> bool:
	return (flags & Flags.ANNOUNCEMENT) != 0


## Returns true if the Denied flag is set
func is_denied() -> bool:
	return (flags & Flags.DENIED) != 0


## Returns true if the Announcement flag is set
func is_allowed() -> bool:
	return (flags & Flags.ALLOWED) != 0


## parses a Dictionary
static func parse_dict(p_dict: Dictionary) -> ConstaNetHeadder:
	var message: ConstaNetHeadder
	
	var p_origin_version: int = type_convert(p_dict.get(A_PROTO_VERSION, -1), TYPE_INT)
	var p_type: int = type_convert(p_dict.get(A_MSG_TYPE, Type.UNKNOWN), TYPE_INT)
	var p_flags: int = type_convert(p_dict.get(A_MSG_FLAGS, Flags.NONE), TYPE_INT)
	var p_origin_id: String = type_convert(p_dict.get(A_MSG_ORIGIN, ""), TYPE_STRING)
	var p_target_id: String = type_convert(p_dict.get(A_MSG_TARGET, ""), TYPE_STRING)
	
	if p_type not in ClassTypes:
		return ConstaNetHeadder.new()
	
	message = ClassTypes[p_type].new()
	message._origin_version = p_origin_version
	message.type = p_type as Type
	message.flags = p_flags
	message.origin_id = p_origin_id
	message.target_id = p_target_id
	
	message._parse_dict(p_dict)
	
	return message


## parses a String
static func parse_string(p_string: String) -> ConstaNetHeadder:
	var data: Variant = JSON.parse_string(p_string)
	
	if not data:
		return ConstaNetHeadder.new()
	
	return parse_dict(data)


## parses a PackedByteArray
static func parse_packet(p_packet: PackedByteArray) -> ConstaNetHeadder:
	if not is_packet_valid(p_packet):
		_network._log_warn("Unable to parse packet. Invalid header!")
		return ConstaNetHeadder.new()
	
	var p_version: int = p_packet.decode_u16(O_PROTO_VERSION)
	var p_type: int = p_packet.decode_u16(O_MSG_TYPE) 
	var p_flags: int = p_packet.decode_u16(O_MSG_FLAGS)
	
	var offset: int = HEADDER_LENGTH_NO_ID
	var p_origin_id: String = p_packet.slice(offset, offset + NODE_ID_LENGTH).get_string_from_ascii()
	
	offset += NODE_ID_LENGTH
	var p_target_id: String = p_packet.slice(offset, offset + NODE_ID_LENGTH).get_string_from_ascii()
	
	if p_type not in ClassTypes:
		return ConstaNetHeadder.new()
	
	var message: ConstaNetHeadder = ClassTypes[p_type].new()
	message._origin_version = p_version
	
	message.type = p_type as Type
	message.flags = p_flags
	message.origin_id = p_origin_id
	message.target_id = p_target_id
	
	message._parse_packet(p_packet.slice(HEADDER_LENGTH))
	return message


## Checks if a given packet is valid
static func is_packet_valid(p_packet: PackedByteArray) -> bool:
	return (
		p_packet.size() >= HEADDER_LENGTH 
		and p_packet.decode_u16(O_PROTO_VERSION) == VERSION
	)


## Converts an IPV4 string to a PackedByteArray
static func get_ipv4_as_buffer(p_ipv4: String) -> PackedByteArray:
	var address: PackedStringArray = p_ipv4.split(".")
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(IPV4_LENGTH)
	
	if address.size() != IPV4_LENGTH:
		return buffer
	
	for index: int in range(address.size()):
		buffer[index] = int(address[index])
	
	return buffer


## Gets an ID as a buffer
static func get_id_as_buffer(p_id: String) -> PackedByteArray:
	var id_array: PackedByteArray = p_id.to_ascii_buffer()
	id_array.resize(NODE_ID_LENGTH)
	
	return id_array


## Encodes the given NodeID at the given offset into the given array
static func encode_node_id(p_offset: int, p_node_id: String, p_array: PackedByteArray) -> void:
	encode_block(p_offset, get_id_as_buffer(p_node_id), p_array)


## Decodes a NodeID at the given offset in the given array
static func decode_node_id(p_offset: int, p_array: PackedByteArray) -> String:
	return decode_block(p_offset, NODE_ID_LENGTH, p_array).get_string_from_ascii()


## Encodes a IPv4 address into the array at the given offset
static func encode_ipv4(p_offset: int, p_ipv4: String, p_array: PackedByteArray) -> void:
	encode_block(p_offset, get_ipv4_as_buffer(p_ipv4), p_array)


## Decodes an IPv4 address from the array at the given offset
static func decode_ipv4(p_offset: int, p_array: PackedByteArray) -> String:
	var buffer: PackedByteArray = decode_block(p_offset, IPV4_LENGTH, p_array)
	var address: String = ""
	
	for octet: int in buffer:
		address += str(octet, ".")
	
	return address.left(-1)


## Encodes a block at the given offset into the given array
static func encode_block(p_offset: int, p_block: PackedByteArray, p_array: PackedByteArray) -> void:
	for index: int in range(p_block.size()):
		p_array[index + p_offset] = p_block[index]


## Decodes a block at the given offset in the given array
static func decode_block(p_offset: int, p_size: int, p_array: PackedByteArray) -> PackedByteArray:
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(p_size)
	
	for index: int in range(buffer.size()):
		buffer[index] = p_array[index + p_offset]
	
	return buffer


## Override this function to provide a method to get the packet as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {}


## Override this function to provide a method to get the packet as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	return []


## Override this function to provide a method to parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	pass


## Override this function to provide a method to parses a Dictionary
func _parse_packet(p_packet: PackedByteArray) -> void:
	pass


## Override this function to provide a method to check if its a valid message
func _is_valid() -> bool:
	return false
