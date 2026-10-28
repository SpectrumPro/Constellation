# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetMultiPart extends ConstaNetHeadder
## ConstaNET MultiPart packet, used to transfer a large message over the network


## Byte length for multi_part_id
const L_PART_ID: TypeLength = TypeLength.NODEID

## Byte length for num_of_chunks
const L_NUM_CHUNKS: TypeLength = TypeLength.UINT16

## Byte length for chunk_id
const L_CHUNK_ID: TypeLength = TypeLength.UINT16

## Byte length for data length
const L_DATA_LENGTH: TypeLength = TypeLength.UINT32

## Byte length for data
const L_DATA_BLOCK: TypeLength = TypeLength.BLOCK


## Byte offset for multi_part_id
const O_PART_ID: int = 0

## Byte offset for num_of_chunks
const O_NUM_CHUNKS: int = O_PART_ID + L_PART_ID

## Byte offset for chunk_id
const O_CHUNK_ID: int = O_NUM_CHUNKS + L_NUM_CHUNKS

## Byte offset for data length
const O_DATA_LENGTH: int = O_CHUNK_ID + L_CHUNK_ID

## Byte offset for data
const O_DATA_BLOCK: int = O_DATA_LENGTH + L_DATA_LENGTH


## String attribute for multi_part_id
const A_PART_ID: String = "multi_part_id"

## String attribute for num_of_chunks
const A_NUM_CHUNKS: String = "num_of_chunks"

## String attribute for chunk_id
const A_CHUNK_ID: String = "chunk_id"

## String attribute for data
const A_DATA_BLOCK: String = "data"


## Message length without the varibal data block
const MESSAGE_SIZE_NO_DATA: int = O_DATA_BLOCK


## The ID of this multipart packet
var multi_part_id: String = ""

## Number of chunks in this multipart message
var num_of_chunks: int = 0

## The ID of this chunk
var chunk_id: int = 0

## Data
var data: PackedByteArray


## init
func _init() -> void:
	type = Type.MULTI_PART


## Gets this ConstaNetMultiPart as a PackedByteArray
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_PART_ID: multi_part_id,
		A_NUM_CHUNKS: num_of_chunks,
		A_CHUNK_ID: chunk_id,
		A_DATA_BLOCK: var_to_str(data)
	}


## Gets this ConstaNetMultiPart as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_SIZE_NO_DATA)
	
	encode_node_id(O_PART_ID, multi_part_id, result)
	
	result.encode_u16(O_NUM_CHUNKS, num_of_chunks)
	result.encode_u16(O_CHUNK_ID, chunk_id)
	
	result.encode_u16(O_DATA_LENGTH, data.size())
	result.append_array(data)
	
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_multi_part_id = type_convert(p_dict.get(A_PART_ID, 0), TYPE_STRING)
	var p_num_of_chunks = type_convert(p_dict.get(A_NUM_CHUNKS, 0), TYPE_INT)
	var p_chunk_id = type_convert(p_dict.get(A_CHUNK_ID, 0), TYPE_INT)
	var p_data = str_to_var(type_convert(p_dict.get(A_DATA_BLOCK, ""), TYPE_STRING))
	
	multi_part_id = p_multi_part_id
	num_of_chunks = p_num_of_chunks
	chunk_id = p_chunk_id
	data = p_data


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_SIZE_NO_DATA:
		_network._log_warn("Unable to parse ConstaNetMultiPart. Packet too short!")
		return
	
	var p_part_id: String = decode_node_id(O_PART_ID, p_packet)
	var p_num_chunks: int = p_packet.decode_u16(O_NUM_CHUNKS)
	var p_chunk_id: int = p_packet.decode_u16(O_CHUNK_ID)
	
	var p_data_length: int = p_packet.decode_u32(O_DATA_LENGTH)
	
	if p_packet.size() < O_DATA_BLOCK + p_data_length:
		_network._log_warn("Unable to parse ConstaNetMultiPart. (p_packet.size() < O_DATA_BLOCK + p_data_length) == true")
		return
	
	var p_data_block: PackedByteArray = decode_block(
		O_DATA_BLOCK, 
		p_data_length, 
		p_packet
	)
	
	multi_part_id = p_part_id
	num_of_chunks = p_num_chunks
	chunk_id = p_chunk_id
	data = p_data_block


## Checks if this ConstaNetMultiPart is valid
func _is_valid() -> bool:
	if multi_part_id and num_of_chunks:
		return true
	
	else:
		return false
