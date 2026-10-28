extends Node2D
# Scene 1 - Anak dan Ibu
# Tugas script ini: baca dialog dari JSON, tampilkan narasi (tengah layar) atau
# kotak dialog (NPC/objek), efek huruf muncul satu per satu, geser kamera, dan fade pembuka.

const FILE_DIALOG := "res://data/dialog_scene2.json"

@export_group("Dialog")
# Seberapa jauh kamera turun saat dialog kotak (makin besar, karakter makin naik ke atas).
# Isi 0 untuk mematikan. Kalau kamera terasa "kedut" sedikit saat dialog mulai/selesai,
# ubah Position Y di Camera2D dari -52 menjadi -55.
@export var geser_kamera_saat_dialog := 49.0
# Warna kotak dialog (solid, tidak transparan).
@export var warna_kotak := Color(0.16, 0.10, 0.09, 1.0)

@export_group("Teks")
# Kecepatan huruf muncul (huruf per detik). Makin besar makin cepat.
# Isi 0 supaya seluruh kalimat langsung tampil.
@export var huruf_per_detik := 40.0
# Kalau true: ketuk saat huruf masih muncul = kalimat langsung tampil penuh.
# Ketukan berikutnya baru lanjut ke kalimat selanjutnya.
@export var klik_untuk_lewati_ketikan := true

@export_group("Narasi")
# Dialog dengan kunci ini tampil sebagai teks di TENGAH layar (tanpa kotak).
@export var kunci_narasi: Array[String] = ["intro"]
@export var ukuran_font_narasi := 32

@export_group("Fade pembuka")
# Layar awal sebelum scene kelihatan. Ganti ke putih kalau mau (Color.WHITE).
@export var warna_layar_awal := Color.BLACK
# Jeda (detik) setelah narasi habis sebelum layar mulai memudar. 0 = langsung memudar.
@export var tahan_layar_awal := 0.0
# Berapa detik layar memudar sampai scene kelihatan jelas.
@export var durasi_fade_intro := 4.0

@export_group("Audio")
# Seret file suara dari panel FileSystem ke kolom-kolom ini (di Inspector node Game).
# Musik mulai setelah layar selesai memudar. Suara api dan burung mulai saat layar mulai memudar.
@export var musik_latar: AudioStream
@export var suara_api: AudioStream
@export var suara_burung: AudioStream
@export_range(-60.0, 6.0, 0.5) var volume_musik_db := -8.0
@export_range(-60.0, 6.0, 0.5) var volume_api_db := -10.0
@export_range(-60.0, 6.0, 0.5) var volume_burung_db := -14.0
# Lama suara masuk pelan-pelan dari senyap (detik)
@export var durasi_masuk_audio := 2.0
# Jarak (px) dari tungku di mana suara api sudah tidak terdengar.
# Makin dekat ke tungku, makin keras.
@export var jarak_dengar_api := 300.0

@export_group("Potret")
# Folder gambar potret visual novel. Isi kolom "potret" di JSON dengan NAMA FILE
# tanpa .png (contoh: "ibu_tertawa").
@export_dir var folder_potret: String = "res://assets/Visual Novel Char/scene_2"

@onready var kotak_dialog = %KotakDialog
@onready var teks = %Teks
@onready var potret = %Potret
@onready var nama_label = get_node_or_null("%Nama")  # opsional: Label bernama "Nama"
@onready var kamera = $Player/Camera2D
@onready var player = $Player

var dialog_data := {}
var baris: Array = []
var index := 0
var kunci_aktif := ""
var limit_bawah_awal := 0
var dialog_aktif := false
var tween_kamera: Tween
var layar_fade: ColorRect
var fade_dimulai := false

# Efek huruf satu per satu
var tween_ketik: Tween
var label_ketik = null
var sedang_mengetik := false

# Teks narasi di tengah layar (dibuat lewat kode)
var lapisan_narasi: CanvasLayer
var label_narasi: Label

# Audio
var ambience_mulai := false
var musik_mulai := false

# Potret
var gambar_potret: Sprite2D
var tekstur_ibu_awal: Texture2D
var potret_bawah := 0.0
var cache_potret := {}


func _ready():
	kotak_dialog.hide()

	# Pastikan lapisan (CanvasLayer) kotak dialog tidak tersembunyi,
	# dan letaknya di atas layar fade.
	var lapisan = kotak_dialog.get_parent()
	if lapisan is CanvasLayer:
		lapisan.visible = true
		lapisan.layer = 2

	_buat_kotak_solid()
	_siapkan_potret()
	limit_bawah_awal = kamera.limit_bottom
	_muat_dialog()
	kotak_dialog.gui_input.connect(_on_dialog_diketuk)

	# Sambungkan semua benda yang bisa diketuk (Ibu, Malin Kecil, Tungku)
	for objek in get_tree().get_nodes_in_group("tappable"):
		objek.diketuk.connect(_on_objek_diketuk)

	# Mulai: layar penuh warna (hitam/putih) + narasi di tengah layar.
	# Fade baru dimulai setelah narasi habis.
	_buat_layar_fade()
	_buat_narasi()
	_mulai_dialog("intro")
	if not dialog_aktif:
		# Narasi gagal dimulai (misal JSON bermasalah): jangan biarkan layar hitam selamanya
		_mulai_fade_intro()


# ---------------------------------------------------------------- tampilan

func _buat_kotak_solid() -> void:
	var panel = kotak_dialog.get_node_or_null("Kotak")
	if panel == null:
		push_warning("Node 'Kotak' tidak ditemukan di dalam KotakDialog.")
		return
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = warna_kotak
	panel.add_theme_stylebox_override("panel", gaya)


func _buat_layar_fade() -> void:
	var lapisan := CanvasLayer.new()
	lapisan.layer = 1  # di bawah kotak dialog (layer 2), di atas dunia game
	layar_fade = ColorRect.new()
	layar_fade.color = warna_layar_awal
	layar_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lapisan.add_child(layar_fade)
	add_child(lapisan)
	layar_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _buat_narasi() -> void:
	lapisan_narasi = CanvasLayer.new()
	lapisan_narasi.layer = 3
	lapisan_narasi.visible = false

	# Penangkap ketukan: seluruh layar (ketuk di mana saja = lanjut)
	var penangkap := Control.new()
	penangkap.mouse_filter = Control.MOUSE_FILTER_STOP
	penangkap.gui_input.connect(_on_dialog_diketuk)

	label_narasi = Label.new()
	label_narasi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_narasi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_narasi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_narasi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_narasi.add_theme_font_size_override("font_size", ukuran_font_narasi)
	label_narasi.add_theme_color_override("font_color", _warna_teks_narasi())

	penangkap.add_child(label_narasi)
	lapisan_narasi.add_child(penangkap)
	add_child(lapisan_narasi)
	penangkap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_narasi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 140)


# Teks putih di layar gelap, teks gelap di layar terang
func _warna_teks_narasi() -> Color:
	var terang := 0.299 * warna_layar_awal.r + 0.587 * warna_layar_awal.g + 0.114 * warna_layar_awal.b
	if terang < 0.5:
		return Color.WHITE
	return Color(0.1, 0.1, 0.1)


func _mulai_fade_intro() -> void:
	if fade_dimulai or not is_instance_valid(layar_fade):
		return
	fade_dimulai = true
	var tween := create_tween()
	tween.tween_interval(tahan_layar_awal)
	tween.tween_callback(_mulai_ambience)  # api & burung mulai saat layar mulai memudar
	tween.tween_property(layar_fade, "color:a", 0.0, durasi_fade_intro)
	tween.tween_callback(_fade_selesai)


func _fade_selesai() -> void:
	if is_instance_valid(layar_fade):
		layar_fade.get_parent().queue_free()
	_mulai_musik()  # musik latar baru mulai setelah fade selesai


# ---------------------------------------------------------------- dialog

func _muat_dialog() -> void:
	var file := FileAccess.open(FILE_DIALOG, FileAccess.READ)
	if file == null:
		push_error("File dialog tidak ketemu: " + FILE_DIALOG)
		return
	var hasil = JSON.parse_string(file.get_as_text())
	if hasil is Dictionary:
		dialog_data = hasil
	else:
		push_error("Isi JSON dialog salah format. Cek koma dan tanda kutipnya.")


func _mode_narasi() -> bool:
	return kunci_aktif in kunci_narasi


# Dipanggil saat Ibu / Malin Kecil / Tungku diketuk.
# Player dikunci, jalan mendekat, lalu dialog baru dibuka setelah player sampai.
func _on_objek_diketuk(kunci: String, objek: Node2D) -> void:
	if dialog_aktif or player.terkunci:
		return  # lagi jalan ke objek lain / lagi dialog: abaikan ketukan
	if kunci == "":
		push_warning("Kunci Dialog masih kosong. Isi di Inspector node '" + objek.name + "'.")
		return
	if not dialog_data.has(kunci):
		push_warning("Kunci dialog tidak ada di JSON: '" + kunci + "'")
		return
	player.dekati(objek, _mulai_dialog.bind(kunci))


func _mulai_dialog(kunci: String) -> void:
	if dialog_aktif:
		return
	if kunci == "":
		push_warning("Kunci Dialog masih kosong. Isi di Inspector node yang diketuk.")
		return
	if not dialog_data.has(kunci):
		push_warning("Kunci dialog tidak ada di JSON: '" + kunci + "'")
		return
	baris = dialog_data[kunci]
	index = 0
	kunci_aktif = kunci
	dialog_aktif = true
	if not _mode_narasi():
		_geser_kamera(true)  # kamera turun hanya untuk dialog kotak
	_tampilkan_baris()


func _tampilkan_baris() -> void:
	var b: Dictionary = baris[index]
	var pembicara: String = b.get("speaker", "")
	var isi: String = b.get("text", "")

	# Narasi: teks di tengah layar, tanpa kotak
	if _mode_narasi():
		kotak_dialog.hide()
		lapisan_narasi.visible = true
		label_narasi.text = isi
		_ketik(label_narasi, 0)
		return

	# NPC / objek: kotak dialog
	lapisan_narasi.visible = false
	kotak_dialog.show()
	var awalan := 0  # jumlah huruf di depan yang langsung tampil (nama pembicara)
	if nama_label != null:
		nama_label.text = pembicara
		teks.text = isi
	elif pembicara != "":
		teks.text = pembicara + "\n" + isi
		awalan = pembicara.length() + 1
	else:
		teks.text = isi

	_atur_potret(b.get("potret", ""))
	_ketik(teks, awalan)


func _lanjut() -> void:
	index += 1
	if index >= baris.size():
		_tutup_dialog()
	else:
		_tampilkan_baris()


func _tutup_dialog() -> void:
	var tadi_narasi := _mode_narasi()
	_hentikan_ketikan()
	sedang_mengetik = false
	kotak_dialog.hide()
	lapisan_narasi.visible = false
	dialog_aktif = false
	baris = []
	index = 0
	kunci_aktif = ""
	if tadi_narasi:
		_mulai_fade_intro()  # narasi habis -> baru layar memudar
	else:
		_geser_kamera(false)
	player.buka_kunci()  # player boleh digerakkan lagi


func _on_dialog_diketuk(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sedang_mengetik:
			if klik_untuk_lewati_ketikan:
				_selesaikan_ketikan()
			return
		_lanjut()


# ---------------------------------------------------------------- huruf satu per satu

func _ketik(label, awal: int) -> void:
	_hentikan_ketikan()
	var jumlah: int = label.text.length()
	if huruf_per_detik <= 0.0 or jumlah <= awal:
		label.visible_characters = -1
		sedang_mengetik = false
		return
	label.visible_characters = awal
	label_ketik = label
	sedang_mengetik = true
	tween_ketik = create_tween()
	tween_ketik.tween_property(label, "visible_characters", jumlah, (jumlah - awal) / huruf_per_detik)
	tween_ketik.tween_callback(_ketikan_selesai)


func _ketikan_selesai() -> void:
	sedang_mengetik = false


func _hentikan_ketikan() -> void:
	if tween_ketik != null and tween_ketik.is_valid():
		tween_ketik.kill()


func _selesaikan_ketikan() -> void:
	_hentikan_ketikan()
	if label_ketik != null:
		label_ketik.visible_characters = -1
	sedang_mengetik = false


# ---------------------------------------------------------------- potret & kamera

func _siapkan_potret() -> void:
	# Node "Gambar Ibu" dipakai sebagai tempat menampilkan SEMUA potret.
	gambar_potret = potret.get_node_or_null("Gambar Ibu") as Sprite2D
	if gambar_potret == null or gambar_potret.texture == null:
		return
	tekstur_ibu_awal = gambar_potret.texture
	# Ingat posisi tepi bawah gambar, supaya potret dengan tinggi berbeda
	# tetap berdiri di garis bawah yang sama.
	potret_bawah = gambar_potret.position.y + gambar_potret.texture.get_height() * gambar_potret.scale.y / 2.0


func _atur_potret(kunci: String) -> void:
	if gambar_potret == null:
		return
	var tekstur := _ambil_potret(kunci)
	if tekstur == null:
		gambar_potret.visible = false
		return
	gambar_potret.texture = tekstur
	gambar_potret.position.y = potret_bawah - tekstur.get_height() * gambar_potret.scale.y / 2.0
	gambar_potret.visible = true


# Cari gambar potret berdasarkan nama file di folder_potret (png / webp / jpg).
func _ambil_potret(kunci: String) -> Texture2D:
	if kunci == "":
		return null
	if cache_potret.has(kunci):
		return cache_potret[kunci]
	var hasil: Texture2D = null
	for akhiran in [".png", ".webp", ".jpg"]:
		var jalur: String = folder_potret.trim_suffix("/") + "/" + kunci + akhiran
		if ResourceLoader.exists(jalur):
			hasil = load(jalur) as Texture2D
			break
	if hasil == null and kunci == "ibu":
		hasil = tekstur_ibu_awal  # gambar lama, dipakai sampai file potret baru ada
	if hasil == null:
		push_warning("Potret tidak ketemu: '" + kunci + "' di folder " + folder_potret)
	cache_potret[kunci] = hasil
	return hasil


# ---------------------------------------------------------------- audio

# Suara api (dari arah tungku) dan burung pagi
func _mulai_ambience() -> void:
	if ambience_mulai:
		return
	ambience_mulai = true

	if suara_api != null:
		var tungku := get_node_or_null("Tungku") as Node2D
		if tungku != null:
			var pemutar_api := AudioStreamPlayer2D.new()
			pemutar_api.max_distance = jarak_dengar_api
			tungku.add_child(pemutar_api)  # ikut posisi tungku
			_putar_loop(pemutar_api, suara_api, volume_api_db)
		else:
			var pemutar_api_biasa := AudioStreamPlayer.new()
			add_child(pemutar_api_biasa)
			_putar_loop(pemutar_api_biasa, suara_api, volume_api_db)

	if suara_burung != null:
		var pemutar_burung := AudioStreamPlayer.new()
		add_child(pemutar_burung)
		_putar_loop(pemutar_burung, suara_burung, volume_burung_db)


func _mulai_musik() -> void:
	if musik_mulai or musik_latar == null:
		return
	musik_mulai = true
	var pemutar_musik := AudioStreamPlayer.new()
	add_child(pemutar_musik)
	_putar_loop(pemutar_musik, musik_latar, volume_musik_db)


# Putar suara berulang-ulang, masuk pelan-pelan dari senyap
func _putar_loop(pemutar, aliran: AudioStream, target_db: float) -> void:
	if aliran is AudioStreamOggVorbis or aliran is AudioStreamMP3:
		aliran.set("loop", true)
	pemutar.stream = aliran
	pemutar.volume_db = -60.0
	pemutar.finished.connect(pemutar.play)  # jaga-jaga: kalau berhenti, putar lagi
	pemutar.play()
	var tween := create_tween()
	tween.tween_property(pemutar, "volume_db", target_db, durasi_masuk_audio)


func _geser_kamera(turun: bool) -> void:
	if geser_kamera_saat_dialog == 0.0:
		return
	# Hentikan gerakan kamera sebelumnya supaya tidak saling tabrakan
	if tween_kamera != null and tween_kamera.is_valid():
		tween_kamera.kill()
	tween_kamera = create_tween()
	if turun:
		kamera.limit_bottom = limit_bawah_awal + int(geser_kamera_saat_dialog) + 5
		tween_kamera.tween_property(kamera, "offset:y", geser_kamera_saat_dialog, 0.25)
	else:
		tween_kamera.tween_property(kamera, "offset:y", 0.0, 0.25)
		tween_kamera.tween_callback(_pulihkan_limit_kamera)


func _pulihkan_limit_kamera() -> void:
	kamera.limit_bottom = limit_bawah_awal
