extends Node

const ENEMY_SCENE := preload("res://enemy.tscn")
const FIRST_INVASION_DELAY := 24.0
const INVASION_INTERVAL := 40.0
const PORTAL_CHARGE_DURATION := 8.0

@export var world_path: NodePath = NodePath("../Level")

@onready var interface: CanvasLayer = $Interface
@onready var surface_overlay: Control = $Interface/SurfaceOverlay
@onready var board: Control = $Interface/SurfaceOverlay/Board
@onready var switch_button: Button = $Interface/TopBar/Margin/Row/SwitchButton
@onready var threat_label: Label = $Interface/TopBar/Margin/Row/ThreatLabel
@onready var portal