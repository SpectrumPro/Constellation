# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name UISessionTree extends Tree
## UI Script for the tree of network sessions


## Tree columns enum
enum Columns {NAME, NODES, SESSION_MASTER, SESSION_ID}


## RefMap for ConstellationSession: TreeItem
var _sessions: RefMap = RefMap.new()

var _session_connections: Dictionary[String, Callable] = {
	"node_joined": _on_node_joined_or_left,
	"node_left": _on_node_joined_or_left,
	"master_changed": _on_session_master_changed,
	"request_delete": _on_session_request_delete,
}


## Ready
func _ready() -> void:
	create_item()
	set_columns(len(Columns))
	
	for column: String in Columns.keys():
		set_column_title(Columns[column], column.capitalize())
	
	Network.session_created.connect(_on_session_created)


## Called when a session is created on the network
func _on_session_created(p_session: ConstellationSession) -> void:
	Utils.connect_signals_with_bind(_session_connections, p_session)
	
	var session_item: TreeItem = create_item()
	
	session_item.set_text(Columns.NAME, p_session.get_name())
	session_item.set_text(Columns.NODES, str(p_session.get_number_of_nodes()))
	session_item.set_text(Columns.SESSION_MASTER, p_session.get_session_master().get_node_name())
	session_item.set_text(Columns.SESSION_ID, p_session.get_session_id())
	
	_sessions.map(p_session, session_item)


## Called when a node joines or leaves a session
func _on_node_joined_or_left(p_node: ConstellationNode, p_session: ConstellationSession) -> void:
	_sessions.left(p_session).set_text(Columns.NODES, str(p_session.get_number_of_nodes()))


## Called when the session master is changed
func _on_session_master_changed(p_node: ConstellationNode, p_session: ConstellationSession) -> void:
	_sessions.left(p_session).set_text(Columns.SESSION_MASTER, p_node.get_node_name())


## Called when a session is to be deleted when all nodes disconnect
func _on_session_request_delete(p_session: ConstellationSession) -> void:
	_sessions.left(p_session).free()
	_sessions.erase_left(p_session)


## Called when the JoinSession Button is pressed
func _on_join_session_pressed() -> void:
	if not get_selected():
		return
	
	Network.join_session(_sessions.right(get_selected()))
