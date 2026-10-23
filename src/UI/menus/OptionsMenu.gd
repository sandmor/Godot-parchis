extends Control
class_name OptionsMenu

signal back_pressed

# Audio sliders and labels
@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterValueLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_label: Label = %MusicValueLabel
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_label: Label = %SFXValueLabel

# Display and gameplay
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var fast_anim_check: CheckBox = %FastAnimCheck
@onready var btn_back: Button = %BtnBack

func _ready() -> void:
	_init_audio_controls()
	_init_display_controls()
	_init_gameplay_controls()
	btn_back.pressed.connect(_on_back_pressed)

func _init_audio_controls() -> void:
	# Default mock values
	master_slider.value = 0.85
	music_slider.value = 0.70
	sfx_slider.value = 0.90
	
	_update_slider_label(master_slider.value, master_label)
	_update_slider_label(music_slider.value, music_label)
	_update_slider_label(sfx_slider.value, sfx_label)
	
	master_slider.value_changed.connect(func(val: float) -> void:
		_update_slider_label(val, master_label)
		_apply_bus_volume("Master", val)
	)
	music_slider.value_changed.connect(func(val: float) -> void:
		_update_slider_label(val, music_label)
		_apply_bus_volume("Music", val)
	)
	sfx_slider.value_changed.connect(func(val: float) -> void:
		_update_slider_label(val, sfx_label)
		_apply_bus_volume("SFX", val)
	)

func _update_slider_label(value: float, label: Label) -> void:
	if label:
		label.text = "%d%%" % int(round(value * 100.0))

func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value))
		AudioServer.set_bus_mute(bus_idx, linear_value <= 0.01)

func _init_display_controls() -> void:
	var mode := DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[OptionsMenu] Modo Pantalla: Pantalla Completa activada.")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("[OptionsMenu] Modo Pantalla: Modo Ventana activado.")

func _init_gameplay_controls() -> void:
	fast_anim_check.button_pressed = false
	fast_anim_check.toggled.connect(func(pressed: bool) -> void:
		print("[OptionsMenu] Animaciones Rápidas (Fast Dice): %s" % ("Activadas" if pressed else "Desactivadas"))
	)

func _on_back_pressed() -> void:
	print("[OptionsMenu] Volviendo al Menú Principal...")
	back_pressed.emit()
