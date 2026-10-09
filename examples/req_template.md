# <Model / modül adı> — <MATLAB | Python>

<!--
Bu şablonu kopyala, köşeli parantezleri doldur, ihtiyacın olmayan satırları sil.
Ne kadar net yazarsan Planner o kadar az soru sorar. Emin olmadığın yerleri boş bırak;
Planner önerilen bir varsayılanla birlikte sorar.
Başlatmak için: /gnc new <bu dosya> <çalışma klasörü> [--lang matlab|python]
-->

## Amaç
<Ne geliştirilecek ve hangi simülasyon/uçuş yazılımında kullanılacak? 1–3 cümle.>
<Bu aşamanın kapsamı: ilk aşamada yalnızca ... ; ... sonraki aşamalara kalacak.>

## Mevcut yapı (değiştirilmeyecek arayüzler)
<!-- Executor yalnızca kendi yazdığı dosyaları görür; mevcut kodunu burada tarif et. -->
- Girdiler: <ör. dinamik struct'ı `sim.dyn` — alanlar: `q_BI` [4x1], `w_BI` [3x1] rad/s, `t` [s]>
- Modelin kendi struct'ı: <ör. `sim.<model>` — konfigürasyon + iç durum alanları>
- Çıktılar: <alan adları, boyutlar, birimler>
- Fonksiyon imzası: <ör. `[y, st] = model_step(in, st)` ve `st = model_init(cfg)`>

## Konvansiyonlar
- Kuaterniyon: <skaler-sonda [q1 q2 q3 q4] | skaler-önde>, <Hamilton | JPL>, <hangi çerçeveden hangisine>
- Çerçeveler: <inertial (ECI J2000), gövde, sensör/aktüatör montaj çerçeveleri>
- Birimler: <SI, açılar rad>; zaman: <örnekleme periyodu, zaman ölçeği>

## İstenen
- <Fonksiyonel gereksinim 1>
- <Fonksiyonel gereksinim 2>
- <Hata/gürültü modelleri, parametreler ve nereden geldikleri (konfigürasyon struct'ı)>

## Kısıtlar
- <MATLAB Coder ile C koduna çevrilecek: codegen uyumlu olmalı, codegen kontrolü kabul kriterine dahil>
- <İzin verilen toolbox'lar / kütüphaneler>
- <Performans, sabit boyutlu bellek, rastgele sayı üretimi ve tekrarlanabilirlik (seed)>

## Doğrulama beklentileri
<!-- Mümkünse sayısal tolerans ver; analitik referanslar ve korunum yasaları en iyi testlerdir. -->
- <Analitik bir durumla karşılaştırma, ör. sabit açısal hızda bilinen çözüm, tolerans ...>
- <Sınır durumları, ör. başlangıç davranışı, parametre sıfır/uç değerlerde>
- <Korunum/özellik kontrolleri, ör. birim norm, enerji, açısal momentum>
- <Gürültü modelleri için istatistik testleri, ör. örnek std ±4σ içinde>

## Kapsam dışı
- <Bu aşamada yapılmayacaklar>
