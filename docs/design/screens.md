# Screens and HUD

**Visual language:** dark varnished wood, cream paper cards, kahvehane signboard lettering, brass accents.
Menus float in front of the live kahvehane scene, so the room is always visible behind them.

> Built (2026-10-30): main menu, "Masa kur" (table page: you + bot levels + rule-set cards; rules page: search, categories, switches and steppers), the Esc menu, the rack buttons and the
> end-of-hand chalkboard. Not built yet: the graphics/sound page, the character creator. Code in `scripts/ui/`.

## Main menu
- The camera slowly drifts around the room; dayıs play at the background tables.
- Entries: **Oyna**, **Nasıl oynanır**, **Çıkış** (Karakter and Ayarlar come with their screens), on a wooden board.

## Lobby
- Four seats around a top-down table sketch. Each seat is "Sen", "Bot (Temkinli / Hırsız)" or, later, "Arkadaş".
- Preset picker: Klasik 101, Kahvehane usulü, Tam kaos, Temiz oyun, or a saved custom preset.
- "Kuralları düzenle" opens the settings page on that preset.

## Settings page (house rules)
- **Tabs:** Açma, Çekme, Cezalar, Bitirme, Maç, Çalma, Mod. Same groups as [101_rules.md](101_rules.md).
- **Each row:** name, short explanation, control (toggle / number stepper / choice), "varsayılan" reset icon.
- A changed row shows a brass dot, so you can see at a glance how a preset differs from Klasik 101.
- Footer buttons: Kaydet (save as preset), Paylaş (copy the JSON), Varsayılana dön.
- Graphics/sound/control settings are a separate "Oyun ayarları" page, kept apart from the house rules.

## In-game HUD
Minimal and partly diegetic.
- **Turn:** a thin ring above the current player's head that drains with the turn timer. "Sıra sende" fades in on your turn.
- **Score:** a small chalkboard top-left with totals. Tab opens the full sheet (hands × players, penalties marked).
- **Rack mode extras:**
  - "En iyi açılış: 87 / 101" from the solver.
  - A Sırala button (by colour or by number).
  - "El Aç" when the opening is valid.
- **Prompts:** `F Yakala!`, `C Taş say`, and the context hint under the crosshair ("Sol tık: çal").
- **Events:** big flash text for caught, stolen and penalty, plus a small event feed bottom-right ("Recep 101 ceza yedi").

## End of hand
- Every rack tips over and shows its tiles.
- The chalkboard fills row by row: rack totals, penalties with reasons, doubling.
- Then "Sonraki el" (next hand) or the match result.

## Character creator
- Your dayı sits in a spotlight on a chair and turns slowly.
- **Tabs:** Yüz (face variant), Bıyık, Saç, Şapka, Kıyafet (shirt/vest colours), Aksesuar (tespih, yüzük, saat).
- Arrows plus colour swatches, and a "Rastgele dayı" button.
- Saved as a small appearance resource (item ids plus colours). Multiplayer only syncs this.
