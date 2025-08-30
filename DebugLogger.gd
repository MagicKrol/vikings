extends RefCounted
class_name DebugLogger

# ============================================================================
# DEBUG LOGGER
# ============================================================================
# 
# Purpose: Centralized debug logging system with configurable categories
# 
# Core Responsibilities:
# - Provide category-based debug output filtering
# - Allow runtime enable/disable of specific debug categories
# - Format debug messages with consistent headers
# - Support detailed logging for complex calculations
# 
# Usage:
# - DebugLogger.log("AIMovement", "Calculating path from region 5 to 12")
# - DebugLogger.enable_category("AIMovement")
# - DebugLogger.disable_category("ResourceManagement")
# ============================================================================

# Static instance for global access
static var _instance: DebugLogger = null

# Debug categories and their enabled state
var debug_categories: Dictionary = {
	# AI Systems
	"AIMovement": false,           # Army movement and pathfinding
	"AIPathfinding": false,        # Detailed pathfinding calculations
	"AIScoring": false,            # Target scoring and evaluation
	"AIPlanning": false,           # Strategic planning decisions
	"AITurnManager": true,        # High-level AI turn processing
	"AIEconomy": false,            # AI economy decisions and raise army
	"AIRecruitment": true,        # AI recruitment and budget allocation
	
	# Resource Systems
	"ResourceManagement": false,   # Resource income and spending
	"ResourceCalculation": false,  # Detailed resource calculations
	
	# Battle Systems
	"BattleSystem": false,         # Combat and battle resolution
	"BattleCalculation": false,    # Detailed battle calculations
	"BattleAnimation": false,      # Battle animation and rounds
	
	# Region Systems
	"RegionManagement": false,     # Region ownership and management
	"RegionScoring": false,        # Region evaluation and scoring
	"MapGeneration": false,        # Map generation and setup
	
	# Castle Systems
	"CastlePlacement": false,      # Castle placement decisions
	"CastleConstruction": false,   # Castle building and upgrades
	
	# Army Systems
	"ArmyManagement": false,       # Army creation and management
	"ArmyComposition": false,      # Army composition and units
	
	# General Systems
	"TurnProcessing": false,       # Turn advancement and processing
	"PlayerManagement": false,     # Player state and management
	"UISystem": false,             # UI interactions and modals
	"InputSystem": false,          # Input handling and processing
	"GameInit": false,             # Game initialization and setup
	"SaveLoad": false,             # Save and load operations
	"Testing": true                # Test framework output
}

# Color coding for different log levels
const COLOR_HEADER = "[color=#00ff00]"      # Green for headers
const COLOR_INFO = "[color=#ffffff]"        # White for info
const COLOR_DETAIL = "[color=#888888]"      # Gray for details
const COLOR_WARNING = "[color=#ffff00]"     # Yellow for warnings
const COLOR_ERROR = "[color=#ff0000]"       # Red for errors
const COLOR_END = "[/color]"

static func _get_instance() -> DebugLogger:
	"""Get or create singleton instance"""
	if _instance == null:
		_instance = DebugLogger.new()
	return _instance

static func log(category: String, message: String, detail_level: int = 0) -> void:
	"""
	Log a debug message if the category is enabled.
	
	Args:
		category: The debug category (e.g., "AIMovement")
		message: The message to log
		detail_level: 0=normal, 1=detailed, 2=verbose
	"""
	var instance = _get_instance()
	
	# Check if category is enabled
	if not instance.debug_categories.get(category, false):
		return
	
	# Format the message with appropriate indentation
	var indent = "  " if detail_level == 1 else "    " if detail_level == 2 else ""
	var formatted_message = "[%s] %s%s" % [category, indent, message]
	
	print(formatted_message)

static func log_calculation(category: String, label: String, value, extra: String = "") -> void:
	"""
	Log a calculation or value with consistent formatting.
	
	Args:
		category: The debug category
		label: Description of the value
		value: The calculated value
		extra: Optional extra information
	"""
	var instance = _get_instance()
	
	if not instance.debug_categories.get(category, false):
		return
	
	var formatted_value = ""
	if value is float:
		formatted_value = str(snappedf(value, 0.001))
	else:
		formatted_value = str(value)
	
	var message = "  %s: %s" % [label, formatted_value]
	if extra != "":
		message += " (%s)" % extra
	
	print("[%s] %s" % [category, message])

static func log_array(category: String, label: String, array: Array, formatter = null) -> void:
	"""
	Log an array with optional formatting.
	
	Args:
		category: The debug category
		label: Description of the array
		array: The array to log
		formatter: Optional callable to format each element
	"""
	var instance = _get_instance()
	
	if not instance.debug_categories.get(category, false):
		return
	
	if array.is_empty():
		print("[%s]   %s: []" % [category, label])
		return
	
	print("[%s]   %s: [" % [category, label])
	for i in range(array.size()):
		var element = array[i]
		if formatter != null and formatter.is_valid():
			element = formatter.call(element)
		print("[%s]     [%d]: %s" % [category, i, str(element)])
	print("[%s]   ]" % category)

static func log_dict(category: String, label: String, dict: Dictionary, formatter = null) -> void:
	"""
	Log a dictionary with optional formatting.
	
	Args:
		category: The debug category
		label: Description of the dictionary
		dict: The dictionary to log
		formatter: Optional callable to format values
	"""
	var instance = _get_instance()
	
	if not instance.debug_categories.get(category, false):
		return
	
	if dict.is_empty():
		print("[%s]   %s: {}" % [category, label])
		return
	
	print("[%s]   %s: {" % [category, label])
	for key in dict:
		var value = dict[key]
		if formatter != null and formatter.is_valid():
			value = formatter.call(value)
		print("[%s]     %s: %s" % [category, str(key), str(value)])
	print("[%s]   }" % category)

static func log_separator(category: String, char: String = "-", length: int = 60) -> void:
	"""Log a separator line for visual organization"""
	var instance = _get_instance()
	
	if not instance.debug_categories.get(category, false):
		return
	
	var separator = ""
	for i in range(length):
		separator += char
	
	print("[%s] %s" % [category, separator])

static func enable_category(category: String) -> void:
	"""Enable debug logging for a specific category"""
	var instance = _get_instance()
	instance.debug_categories[category] = true
	print("[DebugLogger] Enabled category: %s" % category)

static func disable_category(category: String) -> void:
	"""Disable debug logging for a specific category"""
	var instance = _get_instance()
	instance.debug_categories[category] = false
	print("[DebugLogger] Disabled category: %s" % category)

static func set_category(category: String, enabled: bool) -> void:
	"""Set the enabled state for a category"""
	var instance = _get_instance()
	instance.debug_categories[category] = enabled
	print("[DebugLogger] Set category %s to %s" % [category, "enabled" if enabled else "disabled"])

static func enable_all() -> void:
	"""Enable all debug categories"""
	var instance = _get_instance()
	for category in instance.debug_categories:
		instance.debug_categories[category] = true
	print("[DebugLogger] Enabled all categories")

static func disable_all() -> void:
	"""Disable all debug categories"""
	var instance = _get_instance()
	for category in instance.debug_categories:
		instance.debug_categories[category] = false
	print("[DebugLogger] Disabled all categories")

static func enable_ai_debugging() -> void:
	"""Enable all AI-related debug categories"""
	var instance = _get_instance()
	var ai_categories = ["AIMovement", "AIPathfinding", "AIScoring", "AIPlanning", "AITurnManager", "AIEconomy", "AIRecruitment"]
	for category in ai_categories:
		instance.debug_categories[category] = true
	print("[DebugLogger] Enabled AI debugging categories")

static func disable_ai_debugging() -> void:
	"""Disable all AI-related debug categories"""
	var instance = _get_instance()
	var ai_categories = ["AIMovement", "AIPathfinding", "AIScoring", "AIPlanning", "AITurnManager", "AIEconomy", "AIRecruitment"]
	for category in ai_categories:
		instance.debug_categories[category] = false
	print("[DebugLogger] Disabled AI debugging categories")

static func get_enabled_categories() -> Array:
	"""Get list of currently enabled categories"""
	var instance = _get_instance()
	var enabled = []
	for category in instance.debug_categories:
		if instance.debug_categories[category]:
			enabled.append(category)
	return enabled

static func print_status() -> void:
	"""Print the current status of all debug categories"""
	var instance = _get_instance()
	print("[DebugLogger] === Debug Category Status ===")
	for category in instance.debug_categories:
		var status = "✓" if instance.debug_categories[category] else "✗"
		print("[DebugLogger] %s %s" % [status, category])
	print("[DebugLogger] =============================")