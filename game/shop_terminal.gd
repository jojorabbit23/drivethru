# The back-office CRT shop terminal. E opens a menu of three pages (keys 1-4,
# E picks the first thing you can afford):
#   WEAPONS    pistol rounds, the pump shotgun (then its shells)
#   SUPPLIES   buns + toppings, small box or the cheaper big box
#   UPGRADES   the next grill, the heated holding tray, the drive-thru bell
# After a purchase the page stays open, so you can buy twice in a row. The
# screen shows the page you're on and your balance.
extends "res://game/station.gd"

const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")

signal bought(item: String)

var page := ""          # "" (the top menu) | weapons | supplies | upgrades
var _screen: Label3D
var _player: Node

func _ready() -> void:
	add_zone(Vector3(0.6, 0.5, 0.6), Vector3(0, 0.18, 0))
	_screen = Label3D.new()
	_screen.font_size = 18
	_screen.pixel_size = 0.0021
	_screen.modulate = P.ELECTRIC_TEAL
	_screen.outline_size = 0
	_screen.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_screen.position = Vector3(0, 0.18, -0.228)   # just in front of the CRT glass (faces -Z)
	_screen.rotation.y = PI
	add_child(_screen)
	_refresh.call_deferred()

func _process(_delta: float) -> void:
	# back to the top menu once the player has walked away
	if page != "" and _player and _player.get("menu_station") != self:
		page = ""
		_refresh()

func _refresh() -> void:
	var e := economy()
	if e and not e.changed.is_connected(_refresh):
		e.changed.connect(_refresh)
	var title := "SHOP" if page == "" else page.to_upper()
	_screen.text = "%s\n$%d" % [title, e.cash if e else 0]

func prompt(_player_node: Node) -> String:
	return "E  SHOP TERMINAL  ·  $%d" % economy().cash

func interact(player: Node) -> void:
	_player = player
	page = ""
	_open(player)

func _open(player: Node) -> void:
	_refresh()
	player.open_menu(self, options(player))

func _go(player: Node, to: String) -> void:
	page = to
	_open(player)

func options(player: Node) -> Array:
	var e := economy()
	var back := {"label": "Back", "enabled": true, "icon": "back", "action": _go.bind(player, "")}
	match page:
		"weapons":
			var gun: Node = player.get_node_or_null("Head/Camera3D/TestGun")
			var opts := [
				_buy("%d pistol rounds  $%d" % [Economy.AMMO_PACK, Economy.AMMO_PRICE], Economy.AMMO_PRICE, "ammo", buy_ammo.bind(player), gun != null),
			]
			if player.has_weapon("SHOTGUN"):
				opts.append(_buy("%d shotgun shells  $%d" % [Economy.SHELL_PACK, Economy.SHELL_PRICE], Economy.SHELL_PRICE, "shells", buy_shells.bind(player)))
			else:
				opts.append(_buy("Pump shotgun (slot 4)  $%d" % Economy.SHOTGUN_PRICE, Economy.SHOTGUN_PRICE, "shotgun", buy_shotgun.bind(player)))
			opts.append(back)
			return opts
		"supplies":
			return [
				_buy("%d buns + %d toppings  $%d" % [Economy.SUPPLY_PACK, Economy.SUPPLY_PACK, Economy.SUPPLY_PRICE], Economy.SUPPLY_PRICE, "bun", buy_supplies.bind(player)),
				_buy("Big box: %d + %d  $%d" % [Economy.BULK_PACK, Economy.BULK_PACK, Economy.BULK_PRICE], Economy.BULK_PRICE, "crate", buy_bulk.bind(player)),
				back,
			]
		"upgrades":
			var opts := []
			var next: Array = e.next_grill()
			if next.is_empty():
				opts.append({"label": "Grill: %s (maxed)" % e.grill()[0], "enabled": false, "icon": "cooking", "action": func() -> void: pass})
			else:
				var what := "%d slots" % next[1] if int(next[1]) > int(e.grill()[1]) else "longer ready time"
				opts.append(_buy("%s (%s)  $%d" % [next[0], what, next[2]], int(next[2]), "cooking", buy_grill.bind(player)))
			opts.append(_buy("Warming tray: holds %d patties  $%d" % [Economy.TRAY_SLOTS, Economy.TRAY_PRICE], Economy.TRAY_PRICE, "tray", buy_tray.bind(player), not e.has_tray, "Warming tray (installed)"))
			opts.append(_buy("Drive-thru bell: customers wait longer  $%d" % Economy.BELL_PRICE, Economy.BELL_PRICE, "bell", buy_bell.bind(player), not e.has_bell, "Drive-thru bell (installed)"))
			opts.append(back)
			return opts
	return [
		{"label": "Weapons and ammo", "enabled": true, "icon": "shotgun", "action": _go.bind(player, "weapons")},
		{"label": "Kitchen supplies", "enabled": true, "icon": "crate", "action": _go.bind(player, "supplies")},
		{"label": "Upgrades", "enabled": true, "icon": "upgrade", "action": _go.bind(player, "upgrades")},
		{"label": "Close", "enabled": true, "icon": "cancel", "action": func() -> void: pass},
	]

# A purchase row: greyed out when you can't afford it (or already own it).
func _buy(label: String, price: int, icon: String, action: Callable, available := true, owned_label := "") -> Dictionary:
	if not available and owned_label != "":
		return {"label": owned_label, "enabled": false, "icon": icon, "action": action}
	return {"label": label, "enabled": available and economy().cash >= price, "icon": icon, "action": action}

# Every purchase rings the till and leaves the page open for another.
func _done(player: Node, item: String) -> bool:
	Sfx.play(self, "till", -8.0)
	bought.emit(item)
	if player and is_instance_valid(player) and player.get("focus") == self:
		_open(player)
	return true

func buy_ammo(player: Node) -> bool:
	var gun: Node = player.get_node_or_null("Head/Camera3D/TestGun")
	if gun == null or not economy().spend(Economy.AMMO_PRICE):
		return false
	gun.add_ammo(Economy.AMMO_PACK)
	return _done(player, "ammo")

func buy_shotgun(player: Node) -> bool:
	if player.has_weapon("SHOTGUN") or not economy().spend(Economy.SHOTGUN_PRICE):
		return false
	var sg: Node = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	return _done(player, "shotgun")

func buy_shells(player: Node) -> bool:
	var sg: Node = player.weapon_named("SHOTGUN")
	if sg == null or not economy().spend(Economy.SHELL_PRICE):
		return false
	sg.add_ammo(Economy.SHELL_PACK)
	return _done(player, "shells")

func buy_supplies(player: Node = null) -> bool:
	if not economy().spend(Economy.SUPPLY_PRICE):
		return false
	economy().add_supplies(Economy.SUPPLY_PACK)
	return _done(player, "supplies")

func buy_bulk(player: Node = null) -> bool:
	if not economy().spend(Economy.BULK_PRICE):
		return false
	economy().add_supplies(Economy.BULK_PACK)
	return _done(player, "bulk")

func buy_buns() -> bool:
	return buy_supplies()

func buy_grill(player: Node = null) -> bool:
	if not economy().upgrade_grill():
		return false
	return _done(player, "grill")

func buy_tray(player: Node = null) -> bool:
	if not economy().buy_tray():
		return false
	return _done(player, "tray")

func buy_bell(player: Node = null) -> bool:
	if not economy().buy_bell():
		return false
	return _done(player, "bell")
