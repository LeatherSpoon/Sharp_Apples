class_name Tools
## Tool & Gadget slot system.
##
## Tools: one per activity, modify training efficiency, gate dungeon content.
## Gadgets: passive equippables with misc. bonuses, limited slots.

enum ToolTier {
	NONE = 0,
	BASIC = 1,
	IRON = 2,
	STEEL = 3,
	MYTHRIL = 4,
	LEGENDARY = 5,
}

enum GadgetSlotType {
	OFFENSIVE,
	DEFENSIVE,
	UTILITY,
}


class ToolDefinition:
	var id: String
	var tool_name: String
	var activity: int  # Variables.TrainingActivity
	var tier: int  # ToolTier
	var efficiency_multiplier: float = 1.0
	var description: String = ""


class GadgetDefinition:
	var id: String
	var gadget_name: String
	var slot_type: int  # GadgetSlotType
	var effects: Array[Dictionary] = []  # { stat, flat_bonus, percent_bonus }
	var description: String = ""


class EquipmentState:
	var tools: Dictionary = {}  # activity -> ToolDefinition (or null)
	var gadgets: Array[GadgetDefinition] = []
	var max_gadget_slots: int = 1

	func equip_tool(tool_def: ToolDefinition) -> ToolDefinition:
		var prev: ToolDefinition = tools.get(tool_def.activity)
		tools[tool_def.activity] = tool_def
		return prev

	func unequip_tool(activity: int) -> ToolDefinition:
		var prev: ToolDefinition = tools.get(activity)
		tools.erase(activity)
		return prev

	func get_equipped_tool(activity: int) -> ToolDefinition:
		return tools.get(activity)

	func get_tool_tier(activity: int) -> int:
		var t: ToolDefinition = tools.get(activity)
		if t == null:
			return ToolTier.NONE
		return t.tier

	func tool_efficiency(activity: int) -> float:
		var t: ToolDefinition = tools.get(activity)
		if t == null:
			return 1.0
		return t.efficiency_multiplier

	func equip_gadget(gadget: GadgetDefinition) -> bool:
		if gadgets.size() >= max_gadget_slots:
			return false
		gadgets.append(gadget)
		return true

	func unequip_gadget(index: int) -> GadgetDefinition:
		if index < 0 or index >= gadgets.size():
			return null
		var removed := gadgets[index]
		gadgets.remove_at(index)
		return removed

	func expand_gadget_slots(additional: int) -> void:
		if additional > 0:
			max_gadget_slots += additional

	func aggregate_gadget_effects() -> Dictionary:
		var totals: Dictionary = {}  # stat -> { flat, percent }
		for gadget in gadgets:
			for effect in gadget.effects:
				var stat: String = effect["stat"]
				if not totals.has(stat):
					totals[stat] = { "flat": 0.0, "percent": 1.0 }
				totals[stat]["flat"] += effect["flat_bonus"]
				totals[stat]["percent"] *= effect["percent_bonus"]
		return totals
