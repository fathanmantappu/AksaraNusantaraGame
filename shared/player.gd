extends Node2D

const Badan = preload("res://shared/badan.gd")

const SPEED = 50.0

# Batas jalan karakter (kiri-kanan). Ruangan membentang dari x=162 sampai x=498,
# dikurangi lebar karakter supaya badannya tidak tembus dinding.
@export var batas_kiri := 170.0
@export var batas_kanan := 472.0

var target_x = 0.0

# Kalau true, player tidak bisa diatur lewat ketukan di tempat lain.
# Aktif sejak player mengetuk objek, sampai dialognya selesai.
var terkunci := false
# Aksi yang dijalankan sekali saat player sudah sampai di dekat objek (membuka dialog)
var saat_tiba := Callable()

# Ukuran badan player (diukur otomatis dari gambar idle)
var badan_tengah_x := 0.0
var badan_setengah := 7.0

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	target_x = position.x
	var ukur = Badan.ukur(animated_sprite, &"idle", 14.0)
	badan_tengah_x = ukur["tengah_x"]
	badan_setengah = ukur["setengah"]

func _unhandled_input(event):
	if terkunci:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target_x = clamp(get_global_mouse_position().x, batas_kiri, batas_kanan)

func _process(delta):
	var jarak = target_x - position.x

	if abs(jarak) > 1.0:
		animated_sprite.play("Walk")
		animated_sprite.flip_h = jarak < 0
	else:
		animated_sprite.play("idle")

	position.x = move_toward(position.x, target_x, SPEED * delta)

	# Sudah sampai? Jalankan aksi (buka dialog) satu kali saja.
	if saat_tiba.is_valid() and is_equal_approx(position.x, target_x):
		var aksi := saat_tiba
		saat_tiba = Callable()
		aksi.call()

# Dipanggil saat player mengetuk objek/NPC: kunci gerakan, jalan mendekat,
# berhenti di jarak (jarak_berhenti) dari badan objek, lalu jalankan 'aksi'.
func dekati(objek, aksi: Callable) -> void:
	terkunci = true
	saat_tiba = aksi

	var sprite_x: float = animated_sprite.position.x
	var pusat_objek: float = objek.pusat_badan_x()
	var jarak_perlu: float = objek.setengah_badan() + objek.jarak_berhenti + badan_setengah

	# Objek ada di kanan (+1) atau kiri (-1) player?
	var arah := 1.0
	if pusat_objek < global_position.x + sprite_x:
		arah = -1.0
	animated_sprite.flip_h = (arah < 0.0)

	# Titik tengah badan player saat ini (memperhitungkan arah hadap)
	var pusat_pemain := global_position.x + sprite_x + arah * badan_tengah_x

	if abs(pusat_objek - pusat_pemain) <= jarak_perlu:
		target_x = position.x  # sudah cukup dekat, tidak perlu jalan
	else:
		var pusat_tujuan := pusat_objek - arah * jarak_perlu
		target_x = clamp(pusat_tujuan - sprite_x - arah * badan_tengah_x, batas_kiri, batas_kanan)

# Dipanggil setelah dialog selesai
func buka_kunci() -> void:
	if not terkunci:
		return
	terkunci = false
	saat_tiba = Callable()
	target_x = position.x
