---
name: salvar
description: >
  Salva o trabalho do HDEV no GitHub (commit + push). Na primeira vez configura o repositório
  remoto. Use quando o usuário disser "salvar", "salva no github", "commit", "push", "/salvar"
  ou pedir backup do trabalho.
---

# /salvar — Salvar no GitHub

Skill de uma função só: garantir que o trabalho do usuário está no GitHub. Fácil pra quem nunca usou git.

## Workflow

### Passo 0 — Trava de segurança (sempre, antes de qualquer commit)

1. Conferir que `.gitignore` existe na raiz. Se não existir, criar com o conteúdo padrão do template (`.env`, `.env.*`, `!.env.example`, `*.pem`, `*.key`, `credentials*.json`, `node_modules/`, `*.log`) antes de seguir.
2. Se existir `.env` na raiz, confirmar que está ignorado: `git check-ignore .env`. Se não estiver, adicionar `.env` ao `.gitignore` antes de seguir.
3. Depois do `git add .`, varrer o staging (`git diff --cached --name-only`) procurando arquivo suspeito: `.env*` (exceto `.env.example`), nomes contendo `token`, `secret`, `credential`, ou extensões `.pem`/`.key`. Se encontrar, tirar do staging (`git restore --staged <arquivo>`), avisar o usuário e só seguir com o resto.

### Primeira vez (repositório não inicializado)

Detectar com `git rev-parse --is-inside-work-tree`. Se falhar:

1. Perguntar:
   > "Esse é o primeiro syncar. Você já tem um repositório criado no GitHub pra esse workspace?
   > 1. Sim, me passa a URL (ex: https://github.com/usuario/nome.git)
   > 2. Não, vou criar agora — me dá um nome pro repositório (ex: meu-hdev)"

2. **Se opção 1:** rodar `git init`, `git add .`, `git commit -m "Setup inicial do HDEV"`, `git branch -M main`, `git remote add origin <URL>`, `git push -u origin main`.

3. **Se opção 2:** verificar se o `gh` CLI está instalado (`gh --version`). 
   - Se sim: rodar `git init`, criar commit inicial, e `gh repo create <nome> --private --source=. --push`.
   - Se não: instruir o usuário a instalar `gh` (https://cli.github.com/) ou criar o repo manualmente em github.com/new e voltar com a URL.

### Commits seguintes (já configurado)

1. Rodar `git status`. Se não tiver mudanças, responder "Tá tudo sincronizado, sem mudança nova" e parar.

2. Mostrar o `git status` curto pro usuário e perguntar:
   > "Vou comitar tudo isso. Quer descrever a mudança em uma frase ou usa o resumo automático?"

3. Se o usuário fornecer mensagem, usar. Se não, gerar uma mensagem baseada nos arquivos alterados (1 linha, formato: "Atualiza X" ou "Adiciona Y" ou "Cria proposta pra cliente Z").

4. **Registrar no diário** antes do commit (assim a entrada vai junto): adicionar no topo da lista de `_memoria/diario.md` uma linha `- AAAA-MM-DD — <resumo do que foi feito na sessão>` (data de hoje; resumo pode ser a própria mensagem do commit).

5. `git add .` → trava de segurança do Passo 0.3 → `git commit -m "<mensagem>"` → `git push`.

6. Confirmar com link do repositório (extrair de `git remote get-url origin`):
   > "Sincronizado. Ver no GitHub: <URL>"

## Regras

- Nunca usar `--force` sem o usuário pedir explicitamente
- Nunca rodar `git reset --hard` ou outras destrutivas sem confirmação clara
- Se o push falhar por divergência (alguém comitou no remoto), avisar o usuário e oferecer `git pull --rebase` antes de tentar de novo
- Se o usuário ainda não tiver `git` configurado (`user.name` / `user.email`), perguntar e configurar com `git config --global` na primeira vez
