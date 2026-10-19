# The back-office CRT, now the shop terminal: E opens a menu to buy pistol
# ammo and bun supplies with cash. Its screen shows your balance.
extends "res://game/station.gd"

var _screen: Label3D

func _ready() -> void:
	add_zone(Vector3(0.6, 0.5, 0.6), Vector3(0, 0.18, 0))
	_screen = Label3D.new()
	_screen.font_size = 36
	_screen.pixel_size = 0.0011
	_screen.modulate = P.ELECTRIC_TEAL
	_screen.outline_size = 0
	_screen.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_screen.position = Vector3(0, 0.18, -0.228)   # just in front of the CRT glass (faces -Z)
	_screen.rotation.y = PI
	add_child(_screen)
	_refresh.call_deferred()

func _refresh() -> void:
	var e := economy()
	if e and not e.changed.is_connected(_refresh):
		e.changed.connect(_refresh)
	_screen.text = "SHOP\n$%d" % (e.cash if e else 0)

func prompt(_player: Node) -> String:
	return "E  SHOP TERMINAL  ·  $%d" % economy().cash

func interact(player: Node) -> void:
	player.open_menu(self, options(player))

func options(player: Node) -> Array:
	var e := economy()
	var gun: Node = player.get_node_or_null("Head/Camera3D/TestGun")
	return [
		{"label": "%d pistol rounds  $%d" % [Economy.AMMO_PACK, Economy.AMMO_PRICE], "enabled": e.cash >= Economy.AMMO_PRICE and gun != null, "icon": "ammo", "action": buy_ammo.bind(player)},
		{"label": "%d buns  $%d" % [Economy.BUN_PACK, Economy.BUN_PRICE], "enabled": e.cash >= Economy.BUN_PRICE, "icon": "bun", "action": buy_buns},
	]

func buy_ammo(player: Node) -> bool:
	var gun: Node = player.get_node_or_null("Head/Camera3D/TestGun")
	if gun == null or not economy().spend(Economy.AMMO_PRICE):
		return false
	gun.add_ammo(Economy.AMMO_PACK)
	Sfx.play(self, "till", -8.0)
	return true

func buy_buns() -> bool:
	if not economy().spend(Economy.BUN_PRICE):
		return false
	economy().add_buns(Economy.BUN_PACK)
	Sfx.play(self, "till", -8.0)
	return true
