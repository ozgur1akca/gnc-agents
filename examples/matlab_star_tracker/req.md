# Yıldız izleyici (star tracker) sensör modeli — MATLAB

Yüksek doğruluklu ADCS simülasyonum için üreticiden bağımsız (vendor-agnostic), genel bir
yıldız izleyici modeli istiyorum. Bu ilk aşamada yalnızca **ölçüm gecikmesi** kısmı
geliştirilecek; gürültü ve diğer hata kaynakları sonraki aşamalarda eklenecek.

## Mevcut yapı (değiştirilmeyecek arayüzler)
- Dinamik simülatör gerçek kuaterniyon q_B/I ve gövde açısal hızı w_B/I [rad/s] üretir.
- Kuaterniyon konvansiyonu: **skaler-sonda** [q1 q2 q3 q4], q4 skaler.
- Sensör modelleri MATLAB fonksiyonlarıdır; girdi olarak dinamik struct'ı (sim.dyn) ve
  sensörün kendi struct'ını (sim.str: konfigürasyon + iç değişkenler) alır.
  <!-- Alan adlarını kendi kodundaki isimlerle güncelle. -->

## İstenen
- Gecikme = tam sayı kadar sensör örneği + küçük rastgele alt-örnek (sub-sample) gecikme.
- Bir tampon (buffer) ile uygulanacak; tampon uzunluğu konfigürasyondan gelir.
- Alt-örnek gecikme için iki örnek arasında kuaterniyon interpolasyonu (SLERP veya eşdeğeri).
- Sensör fonksiyonları ileride MATLAB Coder ile C koduna çevrilecek: **codegen uyumlu olmalı**
  ve codegen kontrolü kabul kriterlerine dahil edilmeli.

## Doğrulama beklentileri
- Sabit açısal hızda gecikmeli çıktının analitik gecikmeli kuaterniyonla uyumu.
- Gecikme tam sayı örnek olduğunda interpolasyonun etkisiz olması.
- Tampon dolmadan önceki başlangıç davranışının tanımlı olması.
- Çıktı kuaterniyonunun birim normda kalması.
