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
  # Teto de negócios por CONVERSA, contando QUALQUER status — e é o "qualquer"
  # que é o ponto. A idempotência do ActionService#create_deal só enxerga
  # negócio `open`, e entrar em etapa ganha/perdida tira o negócio do `open`
  # (Deal#apply_stage_outcome). Logo criar_negocio -> mover_negocio_da_conversa
  # ("Perdido") -> criar_negocio fecha um ciclo que o modelo repete sozinho
  # dentro de um turno (Ai::ToolLoop::MAX_ITERATIONS = 8), a cada mensagem que
  # chegar. Quem escreve a mensagem é um estranho, então isso é superfície de
  # prompt injection.
  #
  # O dano NÃO fica na conversa do atacante: cada volta publica um card no
  # kanban da CONTA INTEIRA, grava DealActivity e dispara deal.created /
  # deal.stage_changed / deal.won no barramento da Fase 1, que automação e
  # webhook consomem — e um negócio marcado como ganho entra no relatório de
  # receita da agência. Por isso o guard mora AQUI, na tool, e não no prompt: o
  # ActionService tem outros chamadores (macro, automação, humano) e não pode
  # herdar esse teto.
  MAX_DEALS_POR_CONVERSA = 3

  # Recusa em texto, não Ai::ToolError: o modelo deve conseguir repassar isso ao
  # cliente sem parecer que quebrou.
  LIMITE_ATINGIDO = 'Esta conversa já tem negócios demais registrados. Avise que o time comercial vai revisar antes de abrir outro.'.freeze

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
      Há também um teto de negócios por conversa, contando os já fechados: uma
      vez atingido, a ferramenta recusa e não adianta tentar de novo.
    DESC
    schema: SCHEMA
  )

  def call(input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?
    return 'Esta conversa não tem contato associado, então não dá para criar negócio.' if conversation.contact.blank?

    aberto = open_deal
    return "Esta conversa já tem o negócio aberto \"#{aberto.title}\" na etapa \"#{aberto.deal_stage.name}\"." if aberto
    return LIMITE_ATINGIDO if deals_da_conversa >= MAX_DEALS_POR_CONVERSA

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

  # Sem `.open`: negócio ganho/perdido continua ocupando espaço no kanban da
  # conta, é exatamente o que o ciclo produz, e por isso conta pro teto.
  def deals_da_conversa
    account.deals.where(conversation_id: conversation.id).count
  end

  # Etapa ausente devolve nil de propósito: o ActionService cai no default dele
  # (primeira etapa do funil padrão). Etapa informada é resolvida por NOME
  # dentro do funil padrão da conta — id vindo do modelo nunca é aceito. A lista
  # do erro vai truncada: nome de etapa expõe o processo comercial da agência
  # (ver Ai::Tool#vocabulary_sample).
  def resolve_stage(etapa)
    return if etapa.blank?

    stages = DealPipeline.ensure_default!(account).deal_stages.to_a
    stage = stages.find { |candidate| candidate.name.casecmp?(etapa) }
    return stage if stage

    raise Ai::ToolError,
          "A etapa '#{etapa}' não existe no funil padrão. Etapas disponíveis: #{vocabulary_sample(stages.map(&:name))}."
  end
end
