# Plan — voxtype-br (FrancosVox)

## 1. Visão geral
Ditado por voz PT-BR em tempo real no Linux (GNOME Wayland): Voxtype 0.7.1 + GPU (Vulkan/Whisper) + OSD com onda senoidal + inserção automática no foco (`Ctrl+Shift+Espaço`). Baseado no projeto Voxtype (upstream declarado no README).

## 2. Arquitetura e tecnologias
Stack mista: binários Voxtype instalados no sistema, scripts bash (`scripts/`), OSD em `bin/francosvox-osd`, servidor HTTP Whisper (`whisper-http-server.js`), docs opents em `docs/`. Socket `ydotool` restrito e API autenticada em binds externos (hardening 2026-10-11, commits `1a5d115`/`f7159da`).

## 3. Funcionalidades existentes
- [x] Pipeline completo de ditado (atalho → gravação GPU → transcrição 6,5s em 0,67s → colagem) — validado ao vivo (PLANNING.md Fase 1).
- [x] Autostart + OSD senoidal (problemas P1/P2 resolvidos).
- [x] Endurecimento socket/API — publicado em `Version-1.0`.
- [ ] CI — **criada nesta sessão** (compileall, node --check, bash -n, diff-check).

## 4. Objetivos futuros
- OBJ-01 (P2, concluído nesta sessão): CI estática cobrindo os três formatos do repo (py/js/sh).
- OBJ-02 (P3): gerar screenshots via `docs/generate_screenshots.py` em ambiente com GPU (fora da CI por exigir Wayland/audio).
- OBJ-03 (P3, dependente do upstream): acompanhar releases do Voxtype e registrar política de rebase/pin.

## 5–9. Melhorias/Roadmap/Riscos/Ideias
- Risco operacional: scripts aplicam ao sistema real (`/usr/bin`) — qualquer mudança de script exige verificação manual no host do dono, nunca automática.
- `PLANNING.md` é o plano vivo funcional; este `plan.md` é a visão de portfólio; manter ambos sincronizados quando os checkpoints mudarem.

*(Gerado em 2026-10-14 pelo agente orquestrador)*
