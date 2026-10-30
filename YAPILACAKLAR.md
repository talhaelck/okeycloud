# Yapılacaklar

Sneaky Okey'in yol haritası. Bitenin kutusunu işaretle (`[x]`). Ayrıntılı tasarım: [master.md](master.md) ve [docs/design/](docs/design/).

## 1. Temel oyun
- [x] Kahvehane, masa, ıstakalar, taşlar, dağıtma
- [x] Gözlem ve ıstaka modu, buğu (depth of field)
- [x] Gerçekçi birinci şahıs eller (MPFB), parmak tutuşu, parmakla tempo tutma
- [x] Istakada anında sürükle-bırak; yandaki taşlar kayıp yer açar (sırala tuşu yok)
- [x] 101 kural motoru: per, seri, okey, açma barajı, işleme, cezalar, puanlama ([101_rules.md](docs/design/101_rules.md))
- [x] Her ev kuralı bir ayar, hazır setler (`presets/`): Klasik 101, Kahvehane usulü, Tam kaos, Temiz oyun
- [x] Sıra sistemi: desteden ya da soldan çek, aç / işle, at (sürükleyerek; Enter: el aç, R: otomatik diz)
- [x] Masa bölgeleri: ortada tek deste + kalan sayısı, gösterge, çaprazda atılan taş sıraları, önde açma alanları
- [x] Istaka körlüğü: ıstakaya bakarken arkası bulanık ve karanlık
- [x] Botlar 101 oynuyor, gerçek elleriyle (desteden taşı kendine çekiyor)
- [x] Bot kişilikleri: Kartal göz, Temkinli, Usta hırsız (uyanıklık, açgözlülük, değiş tokuş)
- [x] Masaya eğil (W): ortayı kuş bakışı gör, o sırada kendi ıstakan açıkta; herkes eğildiğini görür
- [x] Masa kur'da bot seviyesi (Kolay, Normal, Zor) ve profil adı; karakterler kalktı
- [x] 12-13-1 normal 101'de seri değil (ev kuralı olarak açılabilir)
- [x] Taş dizmeyi pratik yap: tıkla-çek, çift tık at, Ctrl ile çoklu seç, dizme butonları, sayma çizgileri (odada kapatılabilir)

## 2. Ses ve his
- [x] Taş sesleri: tıkırtı, ıstakaya oturma, desteden çekme, masaya atma, dağıtma, menü sesleri
- [ ] Kahvehane ortamı: uğultu, televizyondan maç sesi, kaşığın bardağa vurması, sandalye gıcırtısı
- [ ] Oda yankısı (reverb), sesin yönü belli (3D ses)
- [ ] Dayı sesleri: "cık cık", laf atmalar, gülme

## 3. Fiziksel ve riskli çalma
- [x] Kol masanın üstünden gerçekten uzanır; diğer oyuncular uzanan kolu görür (botlar uzandığı yöne eğilir)
- [x] Çalma bölgeleri: yandaki ıstakalar, atılan taşların herhangi biri, ortadaki deste; kendi taşını ıstakaya koyma (değiş tokuş) ve desteye kaçırma ([stealing.md](docs/design/stealing.md))
- [ ] Açılmış perlerden okey çalma
- [ ] El ve kol çarpışmalı: uzanırken çay bardağına çarparsa bardak şıngırdar, çay dökülür, herkes sese döner
- [ ] Taşlar fizikli: masaya atılan taş seker, kola çarpan taş devrilir
- [x] "Yakala!" tuşu (otomatik yakalama kalktı), "Taş say!" itirazı, 101 ceza, arkadaş modu
- [x] Görülme: 35° net, 70° göz ucu, 0,3 sn tanıklık, koparma anı her zaman görülebilir, çaycı görüşü keser
- [x] Fark etme göstergesi: çalarken bakanların başında "?" / dolan "!"; göz ucu ipucu; Shift ile sessiz ve yavaş
- [x] Botlar da çalar ve botlar da yakalar, eksik taşını fark edip sayar

## 4. Çaycı
- [ ] Masanın etrafında dolaşan çaycı NPC, çay dağıtır, boş bardağı toplar
- [x] Önünden geçtiği an görüşü keser: çalma fırsatı
- [ ] "Ocakçı, iki çay!" diye çağrılabilir

## 5. Kahvehane olayları
- [ ] Televizyonda maç: rastgele "GOOOL!", herkesin dikkati oraya kayar
- [ ] Elektrik kesintisi (karanlık mod)
- [ ] Kapıdan biri girer, kafalar döner
- [ ] Dikkat dağıtma: masaya vurma, tespih şakırdatma ([guncellemeOnerisi.md](guncellemeOnerisi.md))

## 6. Yakalama tekrarı ve klipler
- [ ] Biri yakalanınca son 3 saniye, yakalayanın gözünden ağır çekimde tekrar oynar
- [ ] Bütün ellerin, kafaların ve taşların konumu kare kare kaydedilir (ucuz geri oynatma)
- [ ] Klibi video olarak kaydet / paylaş (TikTok, Shorts)

## 7. Online
- [ ] GodotSteam: Steam lobisi, arkadaş daveti, sunucusuz bağlantı
- [ ] Sunucu-otoriteli: kurallar ve taşların fiziği kurucu oyuncuda çalışır, diğerlerine konumlar gider
- [ ] Sesli sohbet (Steam Voice), konuşan dayının ağzı ve bıyığı oynar
- [ ] Kafa yönü, el pozisyonu, parmak tutuşu senkron

## 8. Görsel ve teknik kalite
- [ ] Gerçek modellenmiş okey taşları: krem bakalit gövde, oyma rakamlar (doku ve normal map), hafif aşınma
- [ ] Oda ışığı önceden hesaplanmış (LightmapGI), yansıma probları, kenar yumuşatma (TAA / FSR)
- [ ] Keçe kumaş shader'ı, masada çay lekesi ve bardak izi (decal), bardaktan buhar, ışıkta toz zerreleri
- [ ] Dayılara iskelet: uzanma, taş alma, işaret etme (Yakala!), gülme, masaya vurma animasyonları; kollarda IK
- [ ] Dayı yüzü: göz kırpma, kaş, ağız açma (sesli sohbet için)
- [ ] Dayılarda deri, kırışıklık ve kumaş detay dokuları (Blender'da bake)
- [ ] Ceza animasyonu: dayıya fizikli şaplak (ragdoll)
- [ ] Performans: orta seviye bilgisayarda 60 FPS

## 9. Ekranlar ([screens.md](docs/design/screens.md))
- [x] Ana menü (kahvehane önünde)
- [x] Lobi (Oda kur): bot kişilikleri, kural ön ayarları, kendi kural setini kaydetme
- [x] Ev kuralları ayar sayfası: her kural Türkçe açıklamasıyla açılıp kapanır, pirinç nokta, varsayılana döndür
- [x] Oyun içi HUD: sıra, süre, puan tablosu, Esc menüsü
- [x] El sonu: kamera bitirene döner, ıstakalar devrilir, kara tahta puanları yazar
- [ ] Karakter oluşturucu: bıyık, kasket, kıyafet, aksesuar
