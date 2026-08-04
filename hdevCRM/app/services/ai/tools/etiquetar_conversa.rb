# Aplica etiquetas (labels) JÁ CADASTRADAS NA CONTA na conversa DESTA conversa.
#
# Emenda de produto à Task 3 (o texto original do plano dizia "cria/associa"):
# quem decide o vocabulário de etiquetas é a agência, a IA só escolhe dentro
# dele. Resolve cada nome contra `account.labels` (título, case-insensitive) e
# aplica sempre o `title` canônico da conta — nunca o texto como o modelo
# escreveu — pra não criar variação por caixa. Nome que não bate com etiqueta
# cadastrada vira Ai::ToolError listando as disponíveis, no mesmo espírito de
# MoverNegocioDaConversa#resolve_stage.
#
# Delega em Labelable#add_labels pra aplicar — a mesma API que o
# ActionService#add_label usa pra macro/automação
# (`@conversation.reload.add_labels(labels)`). Não mexe em `label_list` na
# mão. Só soma com o que a conversa já tinha, nunca substitui.
#
# Escopo só do contexto injetado: nenhum id vem do modelo (ver Ai::ToolRegistry).
#
# ponytail: `add_labels` -> `update!(label_list:)` dispara o
# `after_update_commit` da Conversation (handle_label_change ->
# create_label_change_activity -> Conversations::ActivityMessageJob.
# perform_later) — ESTA tool enfileira job sim, ao contrário do que o
# boilerplate de outras tools da fase diz. O invariante do dry-run continua de
# pé, mas pelo motivo certo: `after_update_commit` só dispara quando a
# transação REAL comita, e o savepoint do dry-run sempre sofre
# ActiveRecord::Rollback antes disso — o enfileiramento nunca chega a
# acontecer em preview. Tool que dependa de side-effect síncrono dentro do
# `call` (não gated por after_commit) precisa de outro desenho.
class Ai::Tools::EtiquetarConversa < Ai::Tool
  SCHEMA = {
    type: 'object',
    properties: {
      etiquetas: {
        type: 'array',
        items: { type: 'string' },
        description: 'Nomes de etiquetas JÁ CADASTRADAS na conta, para aplicar nesta conversa, ex: ["orçamento-enviado", "urgente"].'
      }
    }
  }.freeze

  declare(
    name: 'etiquetar_conversa',
    description: <<~DESC.squish,
      Aplica nesta conversa etiquetas que já existem no cadastro da conta —
      escolhe dentro do vocabulário que a agência definiu, nunca inventa
      etiqueta nova. Chame quando o cliente declarar algo que bate com uma
      etiqueta existente (ex: pediu orçamento e a conta já tem a etiqueta
      "orçamento-enviado"). Nome que não existe na conta devolve erro listando
      as etiquetas disponíveis. Só adiciona, nunca substitui as etiquetas que
      a conversa já tinha. Só afeta esta conversa.
    DESC
    schema: SCHEMA
  )

  def call(input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?

    nomes = etiquetas_from(input)
    return mensagem_atual if nomes.blank?

    cadastradas = account.labels.to_a
    return 'Esta conta ainda não tem etiquetas cadastradas. Peça pra alguém do time criar etiquetas antes.' if cadastradas.blank?

    conversation.reload.add_labels(nomes.map { |nome| resolver(nome, cadastradas) })
    mensagem_atual
  end

  private

  # Lista vazia ou ausente não é erro: só significa "nada novo pra aplicar" —
  # a resposta ainda devolve o estado atual pro modelo.
  def etiquetas_from(input)
    lista = Array(input.to_h.with_indifferent_access[:etiquetas])
    lista.map { |etiqueta| etiqueta.to_s.strip }.reject(&:blank?)
  end

  # Tudo-ou-nada: `nomes.map` levanta no primeiro nome desconhecido, antes de
  # `add_labels` ser chamado — sucesso parcial silencioso é mais difícil do
  # modelo corrigir do que um erro explícito.
  def resolver(nome, cadastradas)
    encontrada = cadastradas.find { |label| label.title.casecmp?(nome) }
    return encontrada.title if encontrada

    raise Ai::ToolError,
          "A etiqueta '#{nome}' não existe nesta conta. Etiquetas disponíveis: #{cadastradas.map(&:title).join(', ')}."
  end

  def mensagem_atual
    atuais = conversation.reload.label_list
    return 'Esta conversa não tem etiquetas no momento.' if atuais.blank?

    "Etiquetas desta conversa: #{atuais.join(', ')}."
  end
end
