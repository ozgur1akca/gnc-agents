# gnc-agents

Uydu AOCS/GNC yazılımı (sensör/aktüatör modelleri, dinamik, kestirim) geliştirmek için
**Claude Code** içinde çalışan Planner ↔ Executor ↔ Critic iş akışı. Claude **Pro** üyeliğiyle
çalışır; API anahtarı gerekmez.

| Rol | Nerede | Model | Görev |
|---|---|---|---|
| Planner / Supervisor | ana sohbet | Opus | Soruları sorar, SPEC + plan + kilitli kabul testlerini yazar, süreci yönetir |
| Executor | `.claude/agents/gnc-executor.md` | Sonnet | Bir görevi kodlar, kendi testlerini yazar, testleri koşar |
| Critic | `.claude/agents/gnc-critic.md` | Opus (salt-okunur) | Testleri kendisi yeniden koşar, kabul testlerinin hash'ini doğrular, GNC açısından inceler |

```
Sorular ──► SPEC + Plan ──(senin onayın)──► Görev: Executor ──► Critic ──(approve)──► sonraki görev / Rapor
                                                   ▲               │
                                                   └───(revise)────┤  4 denemede olmazsa → sana sorar
```

## Kullanım

1. Gereksinimlerini bir `req.md` dosyasına yaz (örnek: [examples/matlab_star_tracker/req.md](examples/matlab_star_tracker/req.md)).
   Mevcut kodundaki struct alan adlarını mutlaka yaz; Executor yalnızca kendi yazdığı dosyaları görür.
2. Bu klasörde Claude Code'u aç ve şunu yaz:
   ```
   /gnc new examples\matlab_star_tracker\req.md D:\workspace\projects\st_delay
   ```
   Seçenekler: `--lang matlab|python` (varsayılan `matlab`), `--auto` (her görevden önce onay sorma).
3. Soruları cevapla, planı onayla, görevleri takip et.
4. Kesinti veya Pro limiti dolarsa: `/gnc resume D:\workspace\projects\st_delay`

Çalışma klasöründe oluşanlar: `src/`, `tests/`, `tests/acceptance/` (kilitli), `codegen_check.m` (codegen
istenirse) ve süreç durumu `.gnc/` (`SPEC.md`, `PLAN.md`, `LOG.md`, `REPORT.md`).

## Güvenceler

- **Kilitli kabul testleri:** Executor'ın `tests/acceptance/` altına yazması hook ile engellenir
  ([.claude/hooks/protect_acceptance.ps1](.claude/hooks/protect_acceptance.ps1)); Critic ayrıca SHA256 hash'lerini kontrol eder.
- **Sert kapı:** Testler Critic'in kendi koşusunda geçmeden, hash'ler tutmadan veya blocker/major sorun varken görev onaylanmaz.
- **MATLAB:** testler kendi makinende, kendi lisansınla `matlab -batch` ile koşar (`matlab` PATH'te olmalı).
  SPEC codegen isterse `codegen_check.m` test komutuna eklenir (MATLAB Coder lisansı gerekir).

## Yapı

```
.claude/skills/gnc/SKILL.md        iş akışı (Planner talimatları)
.claude/agents/gnc-executor.md     Executor ajanı
.claude/agents/gnc-critic.md       Critic ajanı
.claude/hooks/protect_acceptance.ps1
examples/matlab_star_tracker/req.md
```

## Lisans

[MIT](LICENSE)
