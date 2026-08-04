# Cria o negócio (oportunidade) do cliente DESTA conversa no kanban.
#
# Delega a criação ao ActionService#create_deal, que já é idempotente por
# conversa — reimplementar aquele bloco aqui seria duplicar regra de negócio.
# O que a tool acrescenta é resposta: o `create_deal` faz `return` mudo em três
# casos (sem contato, já existe negócio aberto, etapa não encontrada) e o modelo
# precisa saber qual deles aconteceu para decidir o que falar.
#
# Escopo só do contexto injetado: nenhum id vem do modelo (ver Ai::ToolRegistry).
#
# ponytail: nada aqui enfileira job dentro do `call`. O savepoint do dry-run
# desfaz banco, não fila — tool que dispare side-effect assíncrono precisa de
# outro desenho.
class Ai::Tools::CriarNegocio < Ai::Tool
  SCHEMA = {
    type: 'object',
    properties: {
      etapa: {
        type: 'string',
        description: 'Nome da etapa inicial no funil padrão. Omita para começar na primeira etapa.'
      }
    }
  }.freeze

  declare(
    name: 'criar_negocio',
    description: <<~DESC.squish,
      Cria um negócio (oportunidade de venda) no kanban para o cliente desta
      conversa. Chame quando ele demonstrar interesse real: pedir orçamento,
      perguntar preço de um plano, querer contratar. Existe no máximo um negócio
      aberto por conversa — se já houver, a ferramenta avisa em vez de duplicar.
    DESC
    schema: SCHEMA
  )

  def call(input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?
    return 'Esta conversa não tem contato associado, então não dá para criar negócio.' if conversation.contact.blank?

    aberto = open_deal
    return "Esta conversa já tem o negócio aberto \"#{aberto.title}\" na etapa \"#{aberto.deal_stage.name}\"." if aberto

    stage = resolve_stage(input.to_h.with_indifferent_access[:etapa].to_s.strip)
    ActionService.new(conversation).create_deal([stage&.id])

    deal = open_deal
    return 'Não foi possível criar o negócio agora. Avise que o time comercial vai assumir o atendimento.' if deal.nil?

    "Negócio \"#{deal.title}\" criado na etapa \"#{deal.deal_stage.name}\"."
  end

  private

  def open_deal
    account.deals.open.find_by(conversation_id: conversation.id)
  end

  # Etapa ausente devolve nil de propósito: o ActionService cai no default dele
  # (primeira etapa do funil padrão). Etapa informada é resolvida por NOME
  # dentro do funil padrão da conta — id vindo do modelo nunca é aceito.
  def resolve_stage(etapa)
    return if etapa.blank?

    stages = DealPipeline.ensure_default!(account).deal_stages.to_a
    stage = stages.find { |candidate| candidate.name.casecmp?(etapa) }
    return stage if stage

    raise Ai::ToolError,
          "A etapa '#{etapa}' não existe no funil padrão. Etapas disponíveis: #{stages.map(&:name).join(', ')}."
  end
end
