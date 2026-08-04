# Move o negócio aberto DESTA conversa para outra etapa do mesmo funil.
#
# O escopo vem só do contexto injetado (`conversation` + `account`): não existe
# parâmetro de id em lugar nenhum do schema. É isso que limita o raio de um
# prompt injection na mensagem do cliente à própria conversa dele — não há como
# o modelo apontar para negócio de outra conversa nem de outra conta.
#
# ponytail: nada aqui enfileira job dentro do `call`. O savepoint do dry-run
# desfaz banco, não fila — quem adicionar tool que dispare side-effect
# assíncrono (job em after_create, webhook) precisa de outro desenho.
#
# Estilo compacto de propósito: os 5 tools antigos usam módulo aninhado só
# porque estão no `.rubocop_todo.yml`; arquivo novo obedece o
# Style/ClassAndModuleChildren (compact) do repo.
class Ai::Tools::MoverNegocioDaConversa < Ai::Tool
  SCHEMA = {
    type: 'object',
    properties: {
      etapa: {
        type: 'string',
        description: 'Nome da etapa de destino, como aparece no funil (ex: "Proposta Enviada").'
      }
    },
    required: %w[etapa]
  }.freeze

  declare(
    name: 'mover_negocio_da_conversa',
    description: <<~DESC.squish,
      Move o negócio desta conversa para outra etapa do funil de vendas. Chame
      quando a negociação mudar de estágio — o cliente aceitar receber proposta,
      agendar, fechar ou desistir. Só afeta o negócio desta conversa: não existe
      como mover o negócio de outro cliente.
    DESC
    schema: SCHEMA
  )

  def call(input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?

    deal = account.deals.open.find_by(conversation_id: conversation.id)
    return 'Esta conversa não tem negócio aberto. Crie um negócio antes de mover de etapa.' if deal.nil?

    stage = resolve_stage(deal, input.to_h.with_indifferent_access[:etapa].to_s.strip)
    fill_default_lost_reason(deal, stage)
    Deals::MoveService.new(deal: deal, stage: stage).perform

    "Negócio \"#{deal.title}\" movido para a etapa \"#{stage.name}\"."
  end

  private

  # Etapa por NOME, resolvida dentro do funil do próprio negócio. Errar o nome
  # não é falha do modelo, é falta de contexto: a mensagem devolve a lista para
  # ele escolher na iteração seguinte.
  def resolve_stage(deal, etapa)
    stages = deal.deal_pipeline.deal_stages.to_a
    stage = stages.find { |candidate| candidate.name.casecmp?(etapa) }
    return stage if stage

    raise Ai::ToolError,
          "A etapa '#{etapa}' não existe neste funil. Etapas disponíveis: #{stages.map(&:name).join(', ')}."
  end

  # 3º call site do motivo padrão (os outros dois: ActionService#move_deal_stage
  # e Chatbots::Nodes::DealNode). O Deal exige motivo para entrar em etapa
  # perdida e o Deals::MoveService só faz `update!(deal_stage_id:, position:)` —
  # sujar o atributo antes faz aquele mesmo `update!` persistir os dois juntos,
  # sem save extra e sem tocar no MoveService. Motivo já preenchido é mantido.
  def fill_default_lost_reason(deal, stage)
    return unless stage.lost? && deal.lost_reason.blank?

    deal.lost_reason = I18n.t('automation.default_lost_reason')
  end
end
