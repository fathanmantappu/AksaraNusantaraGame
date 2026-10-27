extends RefCounted
# Alat bantu: mengukur lebar "badan" sebuah sprite, yaitu bagian gambar yang
# benar-benar terisi (bukan transparan). Dipakai supaya jarak 8px dihitung
# dari tepi badan yang kelihatan, bukan dari tepi kotak gambar.
#
# Hasil:
#   tengah_x = jarak titik tengah badan dari titik tengah gambar (px, belum dibalik)
#   setengah = setengah lebar badan (px)

static func ukur(sprite: AnimatedSprite2D, nama_animasi: StringName, lebar_cadangan: float) -> Dictionary:
	var hasil := {"tengah_x": 0.0, "setengah": lebar_cadangan / 2.0}
	if sprite == null or sprite.sprite_frames == null:
		return hasil
	if not sprite.sprite_frames.has_animation(nama_animasi):
		return hasil
	var tekstur = sprite.sprite_frames.get_frame_texture(nama_animasi, 0)
	if tekstur == null:
		return hasil
	var gambar: Image = tekstur.get_image()
	if gambar == null or gambar.is_empty():
		return hasil
	var terisi: Rect2i = gambar.get_used_rect()
	if terisi.size.x <= 0:
		return hasil
	var lebar_gambar := float(gambar.get_width())
	hasil["setengah"] = terisi.size.x / 2.0
	hasil["tengah_x"] = (terisi.position.x + terisi.size.x / 2.0) - lebar_gambar / 2.0
	return hasil
