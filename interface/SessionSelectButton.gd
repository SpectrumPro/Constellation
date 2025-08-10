# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name SessionSelectButton extends OptionButton
## Shows sessions in an OptionButton


## Emitted when a session is selected
signal session_selected(session: ConstellationSession)


## All Sessions shown in the list
var _sessions: Array[ConstellationSession]


func _ready() -> void:
	Network.session_created.connect(_on_session_created)
	item_selected.connect(_on_item_selected)
	add_item("None")
	select(0)


## Sets the selected session
func set_selected(p_session: ConstellationSession) -> void:
	select(_sessions.find(p_session) + 1)


## Called when a session is created
func _on_session_created(p_session: ConstellationSession) -> void:
	p_session.request_delete.connect(_on_session_request_delete.bind(p_session), CONNECT_ONE_SHOT)
	
	var index: int = selected
	
	_sessions.append(p_session)
	add_item(p_session.get_name(), _sessions.find(p_session))
	
	select(index)


## Called when a session is to be deleted
func _on_session_request_delete(p_session: ConstellationSession) -> void:
	remove_item(_sessions.find(p_session) + 1)
	_sessions.erase(p_session)
	select(0)


## Called when a session item is selected
func _on_item_selected(p_index: int) -> void:
	if not p_index:
		session_selected.emit(null)
	
	else:
		session_selected.emit(_sessions[p_index - 1])
