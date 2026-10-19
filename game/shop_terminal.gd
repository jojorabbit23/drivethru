# The back-office CRT, now the shop terminal: E opens a menu to buy pistol
# ammo, supplies (buns + toppings) and grill upgrades with cash. Its screen
# shows your balance.
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
	var opts := [
		{"label": "%d pistol rounds  $%d" % [Economy.AMMO_PACK, Economy.AMMO_PRICE], "enabled": e.cash >= Economy.AMMO_PRICE and gun != null, "icon": "ammo", "action": buy_ammo.bind(player)},
		{"label": "%d buns + %d toppings  $%d" % [Economy.SUPPLY_PACK, Economy.SUPPLY_PACK, Economy.SUPPLY_PRICE], "enabled": e.cash >= Economy.SUPPLY_PRICE, "icon": "bun", "action": buy_supplies},
	]
	var next: Array = e.next_grill()
	if not next.is_empty():
		var what := "%d slots" % next[1] if int(next[1]) > int(e.grill()[1]) else "longer ready time"
		opts.append({"label": "%s (%s)  $%d" % [next[0], what, next[2]], "enabled": e.cash >= int(next[2]), "icon": "cooking", "action": buy_grill})
	opts.append({"label": "Cancel", "enabled": true, "icon": "cancel", "action": func() -> void: pass})
	return opts

func buy_ammo(player: Node) -> bool:
	var gun: Node = player.get_node_or_null("Head/Camera3D/TestGun")
	if gun == null or not economy().spend(Economy.AMMO_PRICE):
		return false
	gun.add_ammo(Economy.AMMO_PACK)
	Sfx.play(self, "till", -8.0)
	return true

func buy_supplies() -> bool:
	if not economy().spend(Economy.SUPPLY_PRICE):
		return false
	economy().add_supplies(Economy.SUPPLY_PACK)
	Sfx.play(self, "till", -8.0)
	return true

func buy_buns() -> bool:
	return buy_supplies()

func buy_grill() -> bool:
	if not economy().upgrade_grill():
		return false
	Sfx.play(self, "till", -8.0)
	return true
