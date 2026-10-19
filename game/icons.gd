# Pixel-art icons drawn in code from the 9-colour palette (16x16, nearest
# filtered): order bubbles, grill states, HUD.
#   Icons.texture("burger")   burger | raw | cooking | ready | burnt | mushroom | bun | ammo
extends RefCounted

const P = preload("res://core/palette.gd")
static var _cache := {}

# '.' transparent, then one letter per palette colour.
const KEY := {
	"n": P.MIDNIGHT_TYNE, "s": P.BLUE_SLATE, "c": P.WET_CHARCOAL, "g": P.CONCRETE_GREY,
	"t": P.OXIDISED_TEAL, "e": P.ELECTRIC_TEAL, "o": P.BURNT_ORANGE, "a": P.AMBER_GLOW, "w": P.WARM_CHALK,
}

const ART := {
	"burger": [
		"................",
		"................",
		".....aaaaaa.....",
		"...aawaaawaaa...",
		"..aaaaaaaaawaa..",
		"..aawaaaaaaaaa..",
		"..oooooooooooo..",
		"..tetetetetete..",
		".cccccccccccccc.",
		".cooooccccooooc.",
		".cccccccccccccc.",
		"..aaaaaaaaaaaa..",
		"..oaaaaaaaaaao..",
		"...oooooooooo...",
		"................",
		"................"],
	"raw": [
		"................",
		"................",
		"................",
		"....gggggggg....",
		"..gggwggggwggg..",
		".ggggggggggggggg",
		".gggwggggggwgggg",
		".ggggggggggggggg",
		"..ggggggwggggg..",
		"....gggggggg....",
		"................",
		"......w..w......",
		".....w..w..w....",
		"................",
		"................",
		"................"],
	"cooking": [
		".......a........",
		"......aa........",
		"......aaa...a...",
		".....aoaa..aa...",
		"....aaoaa.aaa...",
		"....aoooaaaoa...",
		"...aaoooaaooa...",
		"...aoowoooooa...",
		"...aowwwoowoa...",
		"...aoowwwowwa...",
		"....aowwwwwa....",
		"....aaowwwoa....",
		".....aaooaa.....",
		"......aaaa......",
		"................",
		"................"],
	"ready": [
		"................",
		"..............e.",
		".............ee.",
		"............eee.",
		"...........eee..",
		"..........eee...",
		".e.......eee....",
		".ee.....eee.....",
		".eee...eee......",
		"..eee.eee.......",
		"...eeeee........",
		"....eee.........",
		".....e..........",
		"................",
		"................",
		"................"],
	"burnt": [
		"................",
		".oo..........oo.",
		".ooo........ooo.",
		"..ooo......ooo..",
		"...ooo....ooo...",
		"....ooo..ooo....",
		".....oooooo.....",
		"......oooo......",
		"......oooo......",
		".....oooooo.....",
		"....ooo..ooo....",
		"...ooo....ooo...",
		"..ooo......ooo..",
		".ooo........ooo.",
		".oo..........oo.",
		"................"],
	"mushroom": [
		"................",
		".....oooooo.....",
		"...oooaooooo....",
		"..oooaaaoooaoo..",
		".ooooaooooaaaoo.",
		".oaooooooooaooo.",
		".oooooooaoooooo.",
		"..cccccccccccc..",
		"......wwww......",
		"......wwww......",
		".....wwwwww.....",
		".....wwwwww.....",
		".....wwwwww.....",
		"....cccccccc....",
		"................",
		"................"],
	"bun": [
		"................",
		"................",
		"................",
		"................",
		".....aaaaaa.....",
		"...aawaaawaaa...",
		"..aaaaaaaaawaa..",
		"..aawaaaaaaaaa..",
		"..aaaaaaaaaaaa..",
		"..oooooooooooo..",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................"],
	"ammo": [
		"................",
		"....a...a...a...",
		"...aaa.aaa.aaa..",
		"...aaa.aaa.aaa..",
		"...ooo.ooo.ooo..",
		"...ooo.ooo.ooo..",
		"...ooo.ooo.ooo..",
		"...ooo.ooo.ooo..",
		"...ooo.ooo.ooo..",
		"...ccc.ccc.ccc..",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................"],
}

static func image(name: String) -> Image:
	var rows: Array = ART[name]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		var row: String = rows[y]
		for x in mini(16, row.length()):
			var k := row[x]
			if KEY.has(k):
				img.set_pixel(x, y, KEY[k])
	return img

static func texture(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = ImageTexture.create_from_image(image(name))
	return _cache[name]

# A billboarded, nearest-filtered sprite for the world (pixel size in metres).
static func sprite(name: String, pixel := 0.012) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = texture(name)
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.no_depth_test = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s
