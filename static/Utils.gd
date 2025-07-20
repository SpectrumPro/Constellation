# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name Utils extends Object
## Usefull function that would be annoying to write out each time


## Contains all the bound signal connections from connect_signals_with_bind()
##	{
##		Object: {
##			Signal: {
##				"CallableName + Callable.get_object_id()": Callable
##			}
##		}
##	}
static var _signal_connections: Dictionary


## Connects all the callables to the signals in the dictionary. Stored as {"SignalName": Callable}
static func connect_signals(signals: Dictionary, object: Object) -> void:
	if is_instance_valid(object):
		for signal_name: String in signals:
			if object.has_signal(signal_name) and not (object.get(signal_name) as Signal).is_connected(signals[signal_name]):
				(object.get(signal_name) as Signal).connect(signals[signal_name])


## Disconnects all the callables from the signals in the dictionary. Stored as {"SignalName": Callable}
static func disconnect_signals(signals: Dictionary, object: Object) -> void:
	if is_instance_valid(object):
		for signal_name: String in signals:
			if object.has_signal(signal_name) and (object.get(signal_name) as Signal).is_connected(signals[signal_name]):
				(object.get(signal_name) as Signal).disconnect(signals[signal_name])



## Connects all the callables to the signals in the dictionary. Also binds the object to the callable. Stored as {"SignalName": Callable}
static func connect_signals_with_bind(signals: Dictionary, object: Object) -> void:
	_signal_connections.get_or_add(object, {})
	
	for signal_name: String in signals:
		if object.has_signal(signal_name):
			var _signal: Signal = object.get(signal_name)
			var connections: Dictionary = _signal_connections[object].get_or_add(_signal, {})
			var bound_callable: Callable = signals[signal_name].bind(object)
			var callable_name: String = bound_callable.get_method() + str(bound_callable.get_object_id())
			
			_signal.connect(bound_callable)
			connections[callable_name] = bound_callable


## Disconnects all the bound callables from the signals in the dictionary. Stored as {"SignalName": Callable}
static func disconnect_signals_with_bind(signals: Dictionary, object: Object) -> void:
	if not _signal_connections.has(object):
		return
	
	for signal_name: String in signals:
		if object.has_signal(signal_name):
			var _signal: Signal = object.get(signal_name)
			var connections: Dictionary = _signal_connections[object].get_or_add(_signal, {})
			var orignal_callable: Callable = signals[signal_name]
			var callable_name: String = orignal_callable.get_method() + str(orignal_callable.get_object_id())
			var bound_callable: Callable = connections[callable_name]
			
			_signal.disconnect(bound_callable)
			connections.erase(callable_name)


## Converts any bitmask enum into a readable string like "FLAG1+FLAG2"
static func flags_to_string(p_flags: int, p_enum: Dictionary) -> String:
	var names: Array[String] = []
	
	for name in p_enum.keys():
		var value: int = p_enum[name]
		
		if value != 0 and (p_flags & value) != 0:
			names.append(name)
	
	return "+".join(names)
