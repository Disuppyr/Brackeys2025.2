extends Control

@export var stats_uis : Array[Control];
@export var hp_uis : Array[ColorRect];
@export var energy_uis : Array[ColorRect];

func _ready() -> void:
	for attributes in GlobalVars.character_attributes:
		stats_uis[attributes.character].visible = !attributes.incapacitated;
		attributes.changed.connect(update_ui.bind(attributes.character));
		update_ui(attributes.character);

func update_ui(character : int):
	hp_uis[character].size.x = 128.0 * (GlobalVars.character_attributes[character].current_hp / float(GlobalVars.character_attributes[character].max_hp));
	energy_uis[character].size.x = 128.0 * (GlobalVars.character_attributes[character].current_energy / float(GlobalVars.character_attributes[character].max_energy));
