class_name GameSettings
extends Resource
## Every house rule of 101 Okey as a setting (docs/design/101_rules.md). Groups match the tabs of the settings page.
## Presets are JSON files holding only the keys they change: built-in ones in res://presets/, the player's own in
## user://presets/. Until the lobby exists: `--preset=<name>` and `--set=<key>=<value>` on the command line.

const PRESET_DIRS := ["res://presets/", "user://presets/"]

## What the room-setup page shows for each setting: [title, explanation]. Settings that are not in the game yet
## (blackout, panic, stealing from melds, showing the gösterge) are left out of HIDDEN's page on purpose.
const LABELS := {
	"open_threshold": ["Açma barajı", "El açmak için indirdiğin perlerin toplam puanı en az bu kadar olmalı."],
	"open_must_beat_previous": ["Öncekini geçmek zorunlu", "Biri daha önce açtıysa, ondan yüksek puanla açmalısın."],
	"open_pairs_enabled": ["Çift açmak serbest", "Perler yerine yan yana çiftlerle de el açılabilir."],
	"open_pairs_min": ["Çift açmak için çift sayısı", "Çiftle açmak için en az bu kadar çift göstermelisin."],
	"pairs_must_beat_previous": ["Çiftte de öncekini geç", "Daha önce çiftle açan varsa, ondan fazla çiftle açmalısın."],
	"run_wraps_13_1": ["12-13-1 seri sayılır", "Normal 101'de yok. Açıksa 1, 13'ün arkasından gelebilir (11 puan sayar)."],
	"pair_opener_can_open_sets": ["Çift açan sonra per de açabilir", "Kapalıysa çiftle açan, o el sadece çift indirir."],
	"pair_opener_can_extend": ["Çift açan işleyebilir", "Çiftle açan, masadaki perlere taş işleyebilir."],
	"okey_swap_from_table": ["Masadaki okeyi alma", "Açtıktan sonra perdeki okeyin yerine gerçek taşını koyup okeyi alırsın."],
	"side_take_requires_open": ["Yandan alan taşı kullanmak zorunda", "Soldakinin attığı taşı alırsan, o taşı aynı el kullanmalısın (açarak ya da işleyerek)."],
	"side_take_penalty": ["Yandan alıp kullanmama cezası", "Yukarıdaki kural bozulursa yazılan ceza."],
	"feed_penalty": ["Açtıran taşı atana ceza", "Sağındakinin el açmasını sağlayan taşı atarsan ceza yersin."],
	"penalty_unit": ["Ceza birimi", "Okey ya da işlek taş atma gibi cezaların büyüklüğü (101)."],
	"not_opened_penalty": ["Hiç açamayanın cezası", "El bittiğinde hiç açamamış oyuncuya yazılan puan."],
	"discard_playable_penalty": ["İşlek taş atma cezası", "Masadaki bir pere işlenebilecek taşı atarsan ceza yersin."],
	"discard_okey_penalty": ["Okey atma cezası", "Okeyi atarsan ceza yersin."],
	"pair_opener_double": ["Çift açanın eli iki kat", "Çiftle açanın elinde kalan taşlar iki kat sayılır."],
	"okey_left_in_hand": ["Elde kalan okeyin puanı", "El bittiğinde ıstakada kalan okey kaç puan yazılır."],
	"finish_bonus": ["Bitirene puan", "Eli bitiren oyuncuya yazılan puan (eksi, yani iyi)."],
	"finish_with_okey_double": ["Okey atarak bitirme iki kat", "Son taş olarak okey atıp bitirirsen bütün puanlar iki katına çıkar."],
	"finish_with_pairs_double": ["Çiftle bitirme iki kat", "Çift açıp bitirirsen bütün puanlar iki katına çıkar."],
	"finish_in_hand_bonus": ["Elden bitirme iki kat", "Hiç açmadan tek hamlede bitirirsen puanlar bir kat daha artar."],
	"hands_per_match": ["Maçtaki el sayısı", "Maç bu kadar elden sonra biter, en düşük puan kazanır."],
	"turn_time_limit": ["Sıra süresi (sn)", "Süre dolunca senin yerine bot oynar. 0 = süre yok."],
	"dealer_tiles": ["Dağıtıcının taş sayısı", "Dağıtıcı bu kadar taşla başlar ve ilk atışı yapar. Diğerleri bir eksik alır."],
	"stealing_enabled": ["Taş çalmak serbest", "Kapalıysa kimse kimsenin taşına dokunamaz."],
	"steal_from_racks": ["Yandaki ıstakadan çal", "Yanındaki oyuncuların ıstakasından taş alabilirsin."],
	"steal_from_discards": ["Atılan taşlardan çal", "Atma yerlerindeki herhangi bir taşı, sıran olmasa da alabilirsin."],
	"steal_from_pile": ["Desteden çal (sıra dışı)", "Sıran değilken desteden taş çekebilirsin."],
	"bots_steal": ["Botlar taş çalar", "Kapalıysa botlar hiç taş çalmaz; sadece sen çalabilirsin."],
	"catch_window": ["Yakalama süresi (sn)", "Çalma bittikten sonra bu süre içinde \"Yakala!\" denebilir."],
	"catch_penalty": ["Yakalanan hırsızın cezası", "Doğru \"Yakala!\" dersen hırsıza yazılan ceza."],
	"false_accusation_penalty": ["Haksız \"Yakala!\" cezası", "Yanlış suçlayana yazılan ceza."],
	"count_check_enabled": ["\"Taş say!\" serbest", "Birinin taşlarını saydırabilirsin."],
	"count_check_penalty": ["\"Taş say!\" cezası", "Kaybedene yazılan ceza: fazla taşı çıkanın ya da boşuna saydıranın."],
	"friend_mode": ["Arkadaş modu", "Hiç ceza yazılmaz. Yakalanmalar sadece duyurulur, gerisini aranızda halledersiniz."],
	"rack_blindness": ["Istaka körlüğü", "Istakana bakarken ekranın geri kalanı ne kadar bulanık ve karanlık olsun (0 = hiç, 1 = tam kör)."],
	"auto_arrange_allowed": ["Diz butonları ve R tuşu", "Istaka görünümünde \"Seri diz\", \"Çift diz\", \"Renge göre\", \"Sayıya göre\" butonları."],
	"group_hints": ["Sayma yardımı", "Istakadaki grupların altında yeşil / kırmızı çizgi ve puan, toplam açılış puanı ve \"El aç\" butonu. Kapalıysa taşlarını kendin sayarsın."],
}

## Settings the page lists no row for: not played yet.
const HIDDEN := ["blackout_mode", "panic_mode", "steal_from_melds", "indicator_show_bonus"]

## Number ranges for the page: key -> [min, max, step]. Whole numbers default to 0-1000, step 1.
const RANGES := {
	"open_threshold": [0, 300, 1], "open_pairs_min": [3, 10, 1], "finish_bonus": [-500, 0, 1],
	"hands_per_match": [1, 30, 1], "turn_time_limit": [0, 180, 5], "dealer_tiles": [15, 24, 1],
	"catch_window": [0.5, 15.0, 0.5], "rack_blindness": [0.0, 1.0, 0.05],
}

@export_group("Açma")
@export var open_threshold := 101
@export var open_must_beat_previous := true
@export var open_pairs_enabled := true
@export var open_pairs_min := 5
@export var pairs_must_beat_previous := false
@export var run_wraps_13_1 := false # 12-13-1 is not a run in standard 101; some tables play it
@export var pair_opener_can_open_sets := false
@export var pair_opener_can_extend := true
@export var okey_swap_from_table := true

@export_group("Çekme")
@export var side_take_requires_open := true
@export var side_take_penalty := 101
@export var feed_penalty := false

@export_group("Cezalar")
@export var penalty_unit := 101
@export var not_opened_penalty := 202
@export var discard_playable_penalty := true
@export var discard_okey_penalty := true
@export var pair_opener_double := true
@export var okey_left_in_hand := 101

@export_group("Bitirme")
@export var finish_bonus := -101
@export var finish_with_okey_double := true
@export var finish_with_pairs_double := true
@export var finish_in_hand_bonus := true

@export_group("Maç")
@export var hands_per_match := 9
@export var turn_time_limit := 30
@export var dealer_tiles := 22
@export var indicator_show_bonus := false

@export_group("Çalma")
@export var stealing_enabled := true
@export var steal_from_racks := true
@export var steal_from_discards := true
@export var steal_from_melds := true
@export var steal_from_pile := true
## The bots may steal too. Off, only you can.
@export var bots_steal := true
@export var catch_window := 4.0
@export var catch_penalty := 101
@export var false_accusation_penalty := 101
@export var count_check_enabled := true
@export var count_check_penalty := 101

@export_group("Mod")
@export var friend_mode := false
@export var blackout_mode := false
@export var panic_mode := false

@export_group("Masa")
@export var rack_blindness := 0.85

@export_group("Yardımcılar")
## Buttons while reading the rack: lay out as best groups / pairs / by colour / by number (R does the first).
@export var auto_arrange_allowed := true
## Counting: lines under the groups on your rack (green = valid, with its points), the total you could open with,
## and an "El aç" button. Off, you count your own tiles.
@export var group_hints := true


## Setting names in declaration order.
func keys() -> Array[String]:
	var out: Array[String] = []
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p.name)
	return out



## The setting groups in declaration order, as the room-setup page tabs: [{title, keys}], without HIDDEN ones.
func groups() -> Array:
	var out := []
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_GROUP:
			out.append({"title": p.name, "keys": []})
		elif p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not out.is_empty() and not HIDDEN.has(p.name):
			out[-1].keys.append(p.name)
	return out.filter(func(g: Dictionary) -> bool: return not g.keys.is_empty())


## One line per setting that differs from the standard rules ("Açma barajı: 81"), for the pause menu.
func summary() -> Array[String]:
	var out: Array[String] = []
	var base := GameSettings.new()
	for key in keys():
		if HIDDEN.has(key) or get(key) == base.get(key):
			continue
		var value: Variant = get(key)
		var shown: String = ("açık" if value else "kapalı") if value is bool else str(value)
		out.append("%s: %s" % [LABELS.get(key, [key])[0], shown])
	return out


## The title a preset file gives itself ("Kahvehane usulü"), or its file name.
static func preset_title(name: String) -> String:
	for dir: String in PRESET_DIRS:
		var path := dir + name + ".json"
		if FileAccess.file_exists(path):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				return data.get("title", name)
	return name


func to_dict() -> Dictionary:
	var out := {}
	for key in keys():
		out[key] = get(key)
	return out


## Only the keys that differ from the defaults (what a preset file holds).
func changes() -> Dictionary:
	var base := GameSettings.new()
	var out := {}
	for key in keys():
		if get(key) != base.get(key):
			out[key] = get(key)
	return out


## Applies known keys, converting JSON numbers and command-line strings to each setting's type.
func apply(values: Dictionary) -> void:
	for key: String in values:
		if not key in self:
			push_warning("Unknown setting: " + key)
			continue
		var current: Variant = get(key)
		var value: Variant = values[key]
		match typeof(current):
			TYPE_BOOL:
				value = value if value is bool else str(value).to_lower() in ["true", "1", "on", "evet"]
			TYPE_INT:
				value = int(value)
			TYPE_FLOAT:
				value = float(value)
		set(key, value)


static func preset(name: String) -> GameSettings:
	var settings := GameSettings.new()
	for dir: String in PRESET_DIRS:
		var path := dir + name + ".json"
		if FileAccess.file_exists(path):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				settings.apply(data.get("rules", {}))
			return settings
	push_warning("No preset named " + name)
	return settings


## Names of all presets (built-in first).
static func preset_names() -> Array[String]:
	var out: Array[String] = []
	for dir: String in PRESET_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".json") and not out.has(file.get_basename()):
				out.append(file.get_basename())
	return out


func save_preset(name: String, title: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://presets")
	var file := FileAccess.open("user://presets/%s.json" % name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"title": title, "rules": changes()}, "\t"))


## Settings from the command line: `--preset=<name>` then any number of `--set=<key>=<value>`.
static func from_command_line() -> GameSettings:
	var settings := GameSettings.new()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--preset="):
			settings = preset(arg.trim_prefix("--preset="))
	for arg in args:
		if arg.begins_with("--set="):
			var pair := arg.trim_prefix("--set=").split("=", true, 1)
			if pair.size() == 2:
				settings.apply({pair[0]: pair[1]})
	return settings
