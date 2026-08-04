# Aplica etiquetas (labels) na conversa DESTA conversa.
#
# Delega pra Labelable#add_labels — a mesma API que o ActionService#add_label
# usa pra macro/automação (`@conversation.reload.add_labels(labels)`). Não
# mexe em `label_list` na mão: acumula com o que a conversa já tinha, sem
# duplicar, e cria a etiqueta na conta se ela ainda não existir.
#
# Escopo só do contexto injetado: nenhum id vem do modelo (ver Ai::ToolRegistry).
#
# ponytail: nada aqui enfileira job dentro do `call`. O savepoint do dry-run
# desfaz banco, não fila — tool que dispare side-effect assíncrono precisa de
# outro desenho.
class Ai::Tools::EtiquetarConversa < Ai::Tool
  SCHEMA = {
    type: 'object',
    properties: {
      etiquetas: {
        type: 'array',
        items: { type: 'string' },
        description: 'Etiquetas para aplicar nesta conversa, ex: ["orçamento-enviado", "urgente"].'
      }
    }
  }.freeze

  declare(
    name: 'etiquetar_conversa',
    description: <<~DESC.squish,
      Aplica etiquetas nesta conversa de atendimento, pra facilitar organização
      e filtro depois. Chame quando identificar algo que vale marcar — motivo do
      contato, urgência, origem. Etiqueta que ainda não existe na conta é criada
      na hora. Não some com etiquetas já aplicadas: só soma. Só afeta esta
      conversa.
    DESC
    schema: SCHEMA
  )

  def call(input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?

    etiquetas = etiquetas_from(input)
    conversation.reload.add_labels(etiquetas) if etiquetas.present?

    atuais = conversation.reload.label_list
    return 'Esta conversa não tem etiquetas no momento.' if atuais.blank?

    "Etiquetas desta conversa: #{atuais.join(', ')}."
  end

  private

  # Lista vazia ou ausente não é erro: só significa "nada novo pra aplicar" —
  # a resposta ainda devolve o estado atual pro modelo.
  def etiquetas_from(input)
    lista = Array(input.to_h.with_indifferent_access[:etiquetas])
    lista.map { |etiqueta| etiqueta.to_s.strip }.reject(&:blank?)
  end
end
