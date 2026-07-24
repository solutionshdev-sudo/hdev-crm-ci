---
name: atualizar-sistema
description: >
  Puxa melhorias do template HDEV (github.com/solutionshdev-sudo/hdev-template) pra esse projeto:
  skills novas, correções em skills existentes, regras do sistema e scripts atualizados.
  Nunca toca na memória do negócio (_memoria/, identidade/, conteúdo produzido).
  Use quando o usuário disser "atualizar sistema", "/atualizar-sistema", "puxa as
  melhorias do template", "atualiza o HDEV".
---

# /atualizar-sistema — Puxar melhorias do template

O projeto foi criado a partir do template HDEV. Quando o template evolui (skill nova, correção, regra melhor), essa skill traz as melhorias **sem tocar no que é do negócio**.

## O que é do sistema (atualizável) vs do negócio (intocável)

| Sistema — pode atualizar | Negócio — NUNCA tocar |
|---|---|
| `_sistema/` | `_memoria/` |
| `.claude/skills/` | `identidade/` |
| `.claude/settings.json` | `CLAUDE.md` da raiz (adaptado no /instalar) |
| `scripts/*.js` e `scripts/README.md` | `marketing/`, `saidas/`, `dados/`, `clientes/` e afins |
| `templates/` | `tarefas.md`, `.env` |
| `.gitignore`, `.env.example`, `VERSION`, `CHANGELOG.md` | |

Exceção do `.gitignore`: se o usuário adicionou linhas próprias, preservar (merge, não sobrescrever).

## Workflow

### Passo 1 — Baixar o template atual

```bash
git clone --depth 1 https://github.com/solutionshdev-sudo/hdev-template.git <scratchpad>/hdev-template
```

Usar pasta temporária. Se o clone falhar (sem internet, repo movido), perguntar a URL correta ou parar.

### Passo 2 — Comparar versões

Ler `VERSION` local e `VERSION` do template.

- Se iguais: "Já está na versão X.Y.Z, nada pra atualizar." e parar (a menos que o usuário queira forçar comparação).
- Se o template for mais novo: ler o `CHANGELOG.md` do template e mostrar o que mudou entre a versão local e a nova.

### Passo 3 — Diff das áreas de sistema

Comparar (ex: `diff -rq`) só as áreas de sistema da tabela acima. Classificar:

- **Novo** — arquivo existe no template e não no projeto (ex: skill nova)
- **Atualizado** — existe nos dois com conteúdo diferente
- **Local** — existe só no projeto (skill criada pelo usuário — NUNCA apagar)

Atenção com skills que o usuário **editou localmente**: se um arquivo difere, mostrar o diff resumido e perguntar antes de sobrescrever (a edição local pode ser proposital).

### Passo 4 — Propor e aplicar

Mostrar lista no formato:

```
Template 1.3.0 (local: 1.1.0). Mudanças disponíveis:

NOVAS:
1. Skill /nome-nova — [descrição em uma linha]

ATUALIZADAS:
2. /salvar — [o que mudou, do changelog]
3. _sistema/regras.md — [o que mudou]

MANTIDAS (só suas): skill /minha-skill-local (não existe no template — intocada)

Aplico todas, escolher algumas, ou nenhuma?
```

Aplicar o que for aprovado, atualizar o `VERSION` local e acrescentar as entradas correspondentes no `CHANGELOG.md` local.

### Passo 5 — Limpeza e registro

- Apagar a pasta temporária do clone
- Sugerir `/salvar` pra versionar a atualização
- Registrar no `_memoria/diario.md`: `- AAAA-MM-DD — Sistema atualizado pra versão X.Y.Z`

## Regras

- **Jamais** tocar em `_memoria/`, `identidade/`, `CLAUDE.md` da raiz ou conteúdo produzido — mesmo que o template tenha versões desses arquivos (lá são placeholders)
- Skill local do usuário que não existe no template: manter sempre
- Arquivo de sistema editado localmente: perguntar antes de sobrescrever, mostrando diff
- Em dúvida, não aplicar — listar e deixar o usuário decidir
