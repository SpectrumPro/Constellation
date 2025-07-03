# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name Details extends RefCounted
## Static class to store program detils


static var version: String = "1.0.0 Beta"

static var schema_version: int = 0

static var copyright: String = "(c) 2025 Liam Sherwin. Licensed under GPL v3."

static var ascii_name: String = """      
   ___             _       _ _      _   _          
  / __|___ _ _  __| |_ ___| | |__ _| |_(_)___ _ _  
 | (__/ _ \\ ' \\(_-<  _/ -_) | / _` |  _| / _ \\ ' \\ 
  \\___\\___/_||_/__/\\__\\___|_|_\\__,_|\\__|_\\___/_||_|
"""



## Function to print all the details
static func print_startup_detils() -> void:
	var colored_text: String = ascii_name

	print(ascii_name, "Version: " + version)
	print()
	print(copyright)
	print()
  
