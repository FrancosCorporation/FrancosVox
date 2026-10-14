# Resumo — voxtype-br (FrancosVox)

## Sessão 2026-10-14 (planejamento padronizado + criação de CI)

- **Resumo executivo:** ferramenta de ditado PT-BR funcional (GPU/Whisper validada ao vivo, ver `PLANNING.md`) e endurecida em 2026-10-11. Estava sem CI; criado workflow estático cobrindo Python (`compileall`), Node (`node --check` do servidor Whisper) e bash (`bash -n` em todos os scripts), além de diff-check.
- **Arquivos:** `.github/workflows/ci.yml` (criado), `plan.md`/`resumo.md` (criados). `PLANNING.md` (plano vivo funcional) mantido intacto.
- **Validações:** `py_compile`/`compileall` passaram localmente; sintaxe JS/sh validada pela CI.
- **Resultado:** [x] CI verde; [x] docs; [x] só `__pycache__` descartado, nada a preservar.
- **Continuidade:** HEAD sincronizado com `origin/Version-1.0`; checkout removível. Scripts do sistema não foram executados (nunca rodar apply.sh fora de janela com o dono).
EOF