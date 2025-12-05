# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetMultiPart extends ConstaNetHeadder
## ConstaNET MultiPart packet


## The ID of this multipart packet
var multi_part_id: String = ""

## Number of chunks in this multipart message
var num_of_chunks: int = 0

## The ID of this chunk
var chunk_id: int = 0

## Data
var data: PackedByteArray


## Init
func _init() -> void:
	type = Type.MULTI_PART


## Gets this ConstaNetCommand as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		"multi_part_id": multi_part_id,
		"num_of_chunks": num_of_chunks,
		"chunk_id": chunk_id,
		"data": var_to_str(data)
	}


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	multi_part_id = type_convert(p_dict.get("multi_part_id", 0), TYPE_STRING)
	num_of_chunks = type_convert(p_dict.get("num_of_chunks", 0), TYPE_INT)
	chunk_id = type_convert(p_dict.get("chunk_id", 0), TYPE_INT)
	data = str_to_var(type_convert(p_dict.get("data", ""), TYPE_STRING))


## Checks if this ConstaNetCommand is valid
func _is_valid() -> bool:
	if multi_part_id and num_of_chunks:
		return true
	
	else:
		return false
