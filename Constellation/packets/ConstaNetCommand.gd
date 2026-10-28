# Copyright (c) Liam Sherwin. All rights reserved.
# This file is part of the Constellation Network Engine.
# Licensed under the GPL v3.0 or later. See the LICENSE.md file for details.

class_name ConstaNetCommand extends ConstaNetHeadder
## ConstaNET Command packet, used to send a command message to one or more nodes in a session


## Byte length for in_session
const L_IN_SESSION: TypeLength = TypeLength.NODEID

## Byte length for data_type
const L_DATA_TYPE: TypeLength = TypeLength.UINT16

## Byte length for command size
const L_DATA_LENGTH: TypeLength = TypeLength.UINT32

## Byte length for the command
const L_COMMAND: TypeLength = TypeLength.BLOCK


## Byte offset for in_session
const O_IN_SESSION: int = 0

## Byte offset for data_type
const O_DATA_TYPE: int = O_IN_SESSION + L_IN_SESSION

## Byte offset for command size
const O_DATA_LENGTH: int = O_DATA_TYPE + L_DATA_TYPE

## Byte offset for command data
const O_COMMAND: int = O_DATA_LENGTH + L_DATA_LENGTH


## String attribute for command DataType
const A_DATA_TYPE: String = "data_type"

## String attribute for command data
const A_COMMAND: String = "command"

## String attribute for session filter
const A_IN_SESSION: String = "in_session"


## Length of this message, excluding the varibal command length
const MSG_LENGTH_NO_COMMAND: int = O_COMMAND


## Datatype of the command
var data_type: int = TYPE_NIL

## Command to send
var command: Variant

## SessionID this command is for
var in_session: String


## init
func _init() -> void:
	type = Type.COMMAND


## Gets this ConstaNetCommand as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_IN_SESSION: in_session,
		A_DATA_TYPE: data_type,
		A_COMMAND: var_to_str(command),
	}


## Gets this ConstaNetCommand as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MSG_LENGTH_NO_COMMAND)
	
	encode_node_id(O_IN_SESSION, in_session, result)
	result.encode_u16(O_DATA_TYPE, data_type)
	
	var command_bytes: PackedByteArray = var_to_bytes(command)
	result.encode_u32(O_DATA_LENGTH, command_bytes.size())
	result.append_array(command_bytes)
	
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_data_type = type_convert(p_dict.get(A_DATA_TYPE, TYPE_NIL), TYPE_INT)
	var p_command = type_convert(str_to_var(p_dict.get(A_COMMAND, "")), p_data_type)
	var p_in_session = type_convert(p_dict.get(A_IN_SESSION, ""), TYPE_STRING)
	
	data_type = p_data_type
	command = p_command
	in_session = p_in_session


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MSG_LENGTH_NO_COMMAND:
		_network._log_warnr("Unable to parse ConstaNetCommand. Packet too short!")
		return
	
	var p_in_session: String = decode_node_id(O_IN_SESSION, p_packet)
	var p_data_type: int = p_packet.decode_u16(O_DATA_TYPE)
	var p_data_length: int = p_packet.decode_u32(O_DATA_LENGTH)
	
	if p_packet.size() < O_COMMAND + p_data_length:
		_network._log_warn("Unable to parse ConstaNetCommand. (p_packet.size() < O_COMMAND + p_data_length) == true")
		return
	
	var p_command: PackedByteArray = p_packet.slice(O_COMMAND, O_COMMAND + p_data_length)
	
	in_session = p_in_session
	data_type = p_data_type as Variant.Type
	command = type_convert(bytes_to_var(p_command), data_type)


## Checks if this ConstaNetCommand is valid
func _is_valid() -> bool:
	if command and data_type and typeof(command) == data_type:
		return true
	
	else:
		return false
