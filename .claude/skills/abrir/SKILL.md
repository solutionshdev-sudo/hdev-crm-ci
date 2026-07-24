---
name: abrir
description: >
  Abre uma sessão de trabalho carregando a memória do negócio (empresa, preferências, estratégia, identidade)
  e devolve um resumo curto pro usuário. Use quando o usuário disser "abrir",
  "começar o dia", "/abrir" ou no primeiro turno de uma sessão depois do /instalar.
---

# /abrir — Abertura de sessão

Curto e direto. O objetivo é carregar contexto e devolver uma síntese de uma frase pra o usuário começar a trabalhar.

## Workflow

1. Ler, em ordem:
   - `_memoria/empresa.md`
   - `_memoria/preferencias.md`
   - `_memoria/estrategia.md`
   - `_memoria/diario.md` (últimas 3 entradas — o que foi feito nas sessões anteriores)
   - `tarefas.md` (seção "Agora", se tiver conteúdo)
   - `identidade/design-guide.md` (só pra saber se está preenchido ou em branco)

2. Se algum dos três primeiros estiver em branco (placeholder), responder:
   > "Vi que `_memoria/<arquivo>.md` ainda não foi preenchido. Quer rodar `/instalar` agora?"
   E parar.

3. Se tudo estiver preenchido, devolver UMA mensagem curta no formato:

```
[Nome do negócio] — [o que faz em 5-8 palavras]
Foco atual: [prioridade da estratégia, em uma frase]
Última sessão: [entrada mais recente do diário, ou "primeira sessão"]
Pendente: [item mais relevante de tarefas.md, se houver]

Pronto. O que vamos fazer?
```

4. Não listar quais arquivos foram lidos. Não confirmar leitura. Só usar o contexto.

## Regras

- Resposta tem que caber em 6 linhas no terminal (omitir "Pendente:" se `tarefas.md` estiver vazio)
- Não fazer perguntas além de "o que vamos fazer?"
- Se o `design-guide.md` estiver em branco, não mencionar — só vira problema quando alguma skill visual for chamada
