extends Node
class_name DebugStepGate

# ============================================================================
# DEBUG STEP GATE
# ============================================================================
# 
# Purpose: Minimal spacebar gate for step-by-step debugging
# 
# Core Responsibilities:
# - Listen for spacebar input during debug mode
# - Provide awaitable step() function for TurnController
# - Handle debug mode toggling
# 
# Usage:
# await debug_step_gate.step()  # Waits for spacebar if debug mode enabled
# ============================================================================

# Debug mode state
var debug_enabled: bool = true  # Default enabled as requested
var step_pending: bool = false
var step_callback: Callable

# Signal for step completion
signal step_completed()

func _ready() -> void:
	"""Initialize debug step gate"""
	print("[DebugStepGate] Initialized with debug mode: ", "enabled" if debug_enabled else "disabled")

func _unhandled_input(event: InputEvent) -> void:
	"""Handle spacebar input for step continuation"""
	if not debug_enabled:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and step_pending:
			print("[DebugStepGate] Spacebar pressed - continuing step")
			_continue_step()

func step() -> void:
	"""Awaitable function that waits for spacebar if debug mode is enabled"""
	if not debug_enabled:
		# Debug mode off - continue immediately
		return
	
	print("[DebugStepGate] Waiting for SPACE to continue...")
	step_pending = true
	
	# Wait for spacebar press
	await step_completed

func _continue_step() -> void:
	"""Continue from step pause"""
	if not step_pending:
		return
	
	step_pending = false
	emit_signal("step_completed")

func set_debug_enabled(enabled: bool) -> void:
	"""Enable or disable debug mode"""
	debug_enabled = enabled
	print("[DebugStepGate] Debug mode ", "enabled" if enabled else "disabled")
	
	# If disabled while waiting, continue immediately
	if not enabled and step_pending:
		_continue_step()

func is_debug_enabled() -> bool:
	"""Check if debug mode is enabled"""
	return debug_enabled