extends RefCounted
class_name PlayerTypeEnum

# ============================================================================
# PLAYER TYPE ENUM
# ============================================================================
# 
# Purpose: Define player types for castle placement and gameplay logic
# 
# Types:
# - HUMAN: Player controlled by user input (click to place castle)
# - COMPUTER: AI controlled player (uses highest scored region)
# - OFF: Inactive player (skips turns completely)
# ============================================================================

enum Type {
	HUMAN,
	COMPUTER,
	OFF
}

# Utility functions
static func type_to_string(type: Type) -> String:
	match type:
		Type.HUMAN:
			return "Human"
		Type.COMPUTER:
			return "Computer"
		Type.OFF:
			return "Off"
		_:
			return "Unknown"

static func from_string(type_string: String) -> Type:
	match type_string.to_lower():
		"human":
			return Type.HUMAN
		"computer":
			return Type.COMPUTER
		"off":
			return Type.OFF
		_:
			return Type.HUMAN  # Default to human
