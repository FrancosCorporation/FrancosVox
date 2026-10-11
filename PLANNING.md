# 📋 Plano de Trabalho — FrancosVox

> Plano vivo do projeto. Marque os itens conforme forem concluídos.

## 🎯 Objetivo

Ditado por voz (voice-to-text) em **Português do Brasil** no Linux (GNOME
Wayland) com **transcrição em tempo real via GPU (Vulkan/Whisper)**, **feedback
visual com onda senoidal animada** conforme a voz, e **inserção automática do
texto na caixa de diálogo** onde o cursor estava — tudo acionado pelo atalho
global `Ctrl+Shift+Espaço`.

---

## ✅ Fase 1 — Diagnóstico (concluída)

- [x] Voxtype 0.7.1 instalado (`/usr/bin/voxtype`, wrapper com suporte a `VOXTYPE_GPU=1`)
- [x] Binário GPU presente: `/usr/lib/voxtype/voxtype-vulkan`
- [x] GPU Vulkan confirmada no log: `AMD Radeon RX 6750 XT (RADV NAVI22)` — `use gpu = 1`
- [x] `voxtype setup check` → todos os checks passam (ydotool, wl-copy, modelo, grupos)
- [x] Atalho GNOME `Ctrl+Shift+Espaço` configurado → `francosvox-toggle`
- [x] Socket de áudio `audio.sock` funciona (703 frames/7s durante gravação)
- [x] Fluxo gravação → transcrição → colagem funciona (6,5s de áudio transcritos em **0,67s** na GPU)

### 🐛 Problemas encontrados

| # | Problema | Causa raiz |
|---|----------|------------|
| P1 | **Atalho morto após reboot** | O daemon **não tem autostart** — só o auto-update sobe no login; `apply.sh` só reinicia o daemon quando há versão nova |
| P2 | **Sem onda senoidal na tela** | O `voxtype-osd` atual é um **ícone de bandeja** (AppIndicator), não um overlay visível na tela |
| P3 | **Inserção fora da caixa de diálogo** | Qualquer janela que roube foco no meio do fluxo joga a colagem no lugar errado (risco com overlay mal feito) |
| P4 | Modelo `large-v3` (3 GB) demora ~12 s para carregar | Config apontava para o modelo grande; o `large-v3-turbo` (1,6 GB, já baixado) carrega em ~1 s na GPU |
| P5 | `README.md` descreve OSD "overlay no topo" mas o código é bandeja | Documentação divergente da realidade |

---

## 🔧 Fase 2 — Correções

### 2.1 Autostart do daemon + recuperação do atalho (P1)

- [x] `~/.config/autostart/francosvox.desktop` executa `francosvox-start` no login
- [x] `scripts/apply.sh` instala autostart do daemon, atualização, bandeja e tradutor
- [x] `scripts/francosvox-toggle`: se o daemon não estiver rodando, **avisar via notificação e iniciá-lo** (auto-recuperação) em vez de falhar em silêncio
- [x] `scripts/francosvox-toggle`: se o estado não existir (daemon subiu agora), aguardar o daemon ficar `idle` antes de enviar `record start`

### 2.2 OSD overlay com onda senoidal (P2)

- [x] Reescrever `bin/francosvox-osd` como **overlay na tela** (não bandeja):
  - Ícone de **speaker/microfone** + **onda senoidal animada** que cresce conforme o volume da voz (lê `audio.sock`)
  - Estado `recording` = vermelho; `transcribing` = azul pulsante; some em idle
  - Ancorado na parte inferior central da tela; pode se sobrepor ao conteúdo, mas é click-through e não recebe foco
- [x] **Sem roubo de foco** (P3):
  - `Gtk.WindowTypeHint.NOTIFICATION` + `set_accept_focus(False)` + `set_skip_taskbar_hint`
  - **Sem** `present()`; apenas `show_all()` na posição definida
  - **Click-through** via input shape vazia
- [x] Manter leitura do `state` (idle/recording/transcribing) via state file

### 2.3 Configuração e GPU (P4)

- [x] `config/config.toml`: `model = "large-v3-turbo"` (rápido + pt-BR excelente)
- [x] Configurar `pre_type_delay_ms = 800` e `mode = "file"`; `francosvox-toggle` entrega a transcrição após o daemon voltar a `idle`
- [x] `scripts/francosvox-start`: detectar o binário Vulkan e fazer fallback disponível

### 2.4 Testes (P3)

- [x] Reiniciar sessão/daemon → atalho funciona sem comando manual
- [x] Gravar → onda anima com a voz (speaker se move)
- [x] Transcrever → texto cai **na caixa de diálogo focada** (não em outra janela) — stall do wtype eliminado
- [x] Transcrição em tempo real (GPU): 6,5s de áudio → ~0,7s

---

## 📖 Fase 3 — Documentação e publicação

- [x] Reescrever `README.md` (público, bonito, com badges e screenshots)
- [x] Atualizar `docs/generate_screenshots.py` para o novo OSD overlay
- [x] Gerar screenshots/GIF: recording (onda animada) + transcribing + hero mockup
- [x] Atualizar `docs/SETUP.md` e `docs/TROUBLESHOOTING.md` (wtype removido, OSD overlay, autostart)
- [x] Verificar `config.toml` sem dados pessoais: contém apenas idiomas, modelo e caminhos genéricos
- [ ] `git push` para `origin` (FrancosCorporation/voxtype-br)
- [ ] Conferir o README renderizado no GitHub
- [x] Release/tag não necessária para esta revisão; a release existente `v1.1.0` não foi alterada

---

## 📌 Estado atual

- [x] Fase 1 concluída — diagnóstico completo
- [x] Fase 2 concluída — correções (inclui fix do stall de colagem de ~50s: remoção do wtype + limpeza do clipboard)
- [ ] Fase 3 em andamento — documentação atualizada; commit, push e conferência online pendentes

## Atualização de implementação — 2026-10-11

- O instalador agora configura o socket privilegiado do `ydotoold` com dono UID/GID numéricos e permissão `0600`; os comandos manuais dos guias seguem o mesmo padrão.
- A API opcional `/transcribe` permanece no loopback por padrão; binds externos exigem `WHISPER_TOKEN` com pelo menos 32 bytes. Limites de corpo/fila, validação estrita de WAV, temporário `0600` e erros genéricos foram adicionados.
- README, guia de setup e troubleshooting alinhados aos nomes atuais, `mode = "file"`, espera de 800 ms e posição real do OSD. O benchmark de GPU está identificado como resultado de um teste local, não como tempo universal.
- `config/config.toml` foi revisado e não contém dados pessoais. Revisão online do README e push ainda pendentes.
