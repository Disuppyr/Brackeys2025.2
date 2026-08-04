extends Control

@export var stats_uis : Array[Control];
@export var hp_uis : Array[ColorRect];
@export var energy_uis : Array[ColorRect];
@export var hp_labels : Array[Label];
@export var energy_labels : Array[Label];
@export var item_label : Label;

const HP_COLOR := Color(0.392157, 1, 0.392157, 0.784314);
const HP_LOW_COLOR := Color(1.0, 0.3, 0.3, 0.9);
const ENERGY_COLOR := Color(0.392157, 1, 1, 0.784314);
const ENERGY_READY_COLOR := Color(1.0, 0.85, 0.2, 1.0);
const FLASH_COLOR := Color(1, 1, 1, 1);
const INCAPACITATED_ALPHA := 0.35;
const LOW_HP_THRESHOLD := 0.25;

var last_hp : Array[int] = [0, 0, 0, 0];
var last_energy : Array[int] = [0, 0, 0, 0];

func _ready() -> void:
	for attributes in GlobalVars.character_attributes:
		last_hp[attributes.character] = attributes.current_hp;
		last_energy[attributes.character] = attributes.current_energy;
		attributes.changed.connect(update_ui.bind(attributes.character));
		update_ui(attributes.character);
	GlobalVars.held_item_changed.connect(update_item_label);
	update_item_label();

func update_item_label() -> void:
	if not item_label:
		return;
	var item_name = GlobalVars.get_held_item_name();
	item_label.text = ("Item: " + item_name) if item_name != "" else "";

func update_ui(character : int):
	var attributes = GlobalVars.character_attributes[character];

	stats_uis[character].modulate.a = INCAPACITATED_ALPHA if attributes.incapacitated else 1.0;

	var hp_fraction = float(attributes.current_hp) / float(attributes.max_hp);
	var hp_color = HP_LOW_COLOR if hp_fraction <= LOW_HP_THRESHOLD else HP_COLOR;
	hp_uis[character].size.x = 128.0 * hp_fraction;
	hp_uis[character].color = hp_color;
	if character < hp_labels.size() and hp_labels[character]:
		hp_labels[character].text = "%d/%d" % [attributes.current_hp, attributes.max_hp];
	if attributes.current_hp != last_hp[character]:
		_flash(hp_uis[character], hp_color);
		last_hp[character] = attributes.current_hp;

	var energy_fraction = float(attributes.current_energy) / float(attributes.max_energy);
	var special_ready = attributes.current_energy >= attributes.special_cost;
	var energy_color = ENERGY_READY_COLOR if special_ready else ENERGY_COLOR;
	energy_uis[character].size.x = 128.0 * energy_fraction;
	energy_uis[character].color = energy_color;
	if character < energy_labels.size() and energy_labels[character]:
		energy_labels[character].text = "%d/%d" % [attributes.current_energy, attributes.max_energy];
	if attributes.current_energy != last_energy[character]:
		_flash(energy_uis[character], energy_color);
		last_energy[character] = attributes.current_energy;

func _flash(bar : ColorRect, return_color : Color) -> void:
	bar.color = FLASH_COLOR;
	var tween = create_tween();
	tween.tween_property(bar, "color", return_color, 0.25);
