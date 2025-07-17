# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name UISessionTree extends Tree
## UI Script for the tree of network sessions


## Tree columns enum
enum Columns {NAME, NODES, SESSION_ID}


## RefMap for ConstellationSession: TreeItem
var _sessions: RefMap = RefMap.new()


## Ready
func _ready() -> void:
	create_item()
	set_columns(len(Columns))
	
	for column: String in Columns.keys():
		set_column_title(Columns[column], column.capitalize())
	
	Network.session_created.connect(_on_session_created)


## Called when a session is created on the network
func _on_session_created(p_session: ConstellationSession) -> void:
	var session_item: TreeItem = create_item()
	
	session_item.set_text(Columns.NAME, p_session.get_name())
	session_item.set_text(Columns.NODES, str(p_session.get_number_of_nodes()))
	session_item.set_text(Columns.SESSION_ID, p_session.get_session_id())
	
	_sessions.map(p_session, session_item)


## Called when the JoinSession Button is pressed
func _on_join_session_pressed() -> void:
	if not get_selected():
		return
	
	Network.join_session(_sessions.right(get_selected()))
