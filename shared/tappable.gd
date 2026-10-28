extends Node2D
# Pasang script ini di NPC / benda yang boleh diketuk (Ibu, Malin Kecil, Tungku).
# Script ini otomatis membuat "stiker peka sentuh" (Area2D) seukuran gambarnya.

const Badan = preload("res://shared/badan.gd")

signal diketuk(kunci: String, objek: Node2D)

# Nama dialog di file JSON, contoh: "percakapan" atau "tungku"
@export var kunci_dialog := ""
# 1.0 = sebesar gambar. Naikkan (misal 1.3) kalau di HP susah diketuk.
@export_range(0.5, 2.0, 0.05) var skala_area := 1.0
# Dipakai hanya kalau gambar (AnimatedSprite2D) tidak ditemukan.
@export var ukuran_cadangan := Vector2(32, 32)

@export_group("Jarak berhenti")
# Jarak kosong (px) antara badan player dan badan objek saat player berhenti.
@export var jarak_berhenti := 8.0
# Lebar badan objek (px). Isi 0 supaya diukur otomatis dari gambar.
@export var lebar_badan := 0.0

var _badan_tengah_lokal := 0.0
var _badan_setengah := 16.0


func _ready():
	add_to_group("tappable")

	var ukuran := ukuran_cadangan
	var tengah := Vector2.ZERO

	var sprite := _cari_sprite()
	if sprite != null and sprite.sprite_frames != null:
		var tekstur := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if tekstur != null:
			ukuran = tekstur.get_size()
			if sprite != self:
				tengah = sprite.position

	# Ukur badan objek (untuk menentukan titik berhenti player)
	_badan_setengah = ukuran.x / 2.0
	_badan_tengah_lokal = tengah.x
	if sprite != null:
		var hasil := Badan.ukur(sprite, sprite.animation, ukuran.x)
		_badan_setengah = hasil["setengah"]
		_badan_tengah_lokal = tengah.x + hasil["tengah_x"]
	if lebar_badan > 0.0:
		_badan_setengah = lebar_badan / 2.0

	var area := Area2D.new()
	area.monitoring = false
	area.monitorable = false

	var bentuk := CollisionShape2D.new()
	var kotak := RectangleShape2D.new()
	kotak.size = ukuran * skala_area
	bentuk.shape = kotak
	bentuk.position = tengah

	area.add_child(bentuk)
	add_child(area)
	area.input_event.connect(_on_area_input)


# Posisi x (dunia) titik tengah badan objek
func pusat_badan_x() -> float:
	return global_position.x + _badan_tengah_lokal


func setengah_badan() -> float:
	return _badan_setengah


func _cari_sprite() -> AnimatedSprite2D:
	var diri: Node = self  # dianggap Node biasa supaya Godot mau ngecek tipenya
	if diri is AnimatedSprite2D:
		return diri as AnimatedSprite2D
	for anak in get_children():
		if anak is AnimatedSprite2D:
			return anak
	return null


func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		diketuk.emit(kunci_dialog, self)
