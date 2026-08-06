# Encerra o atendimento automático DESTA conversa e chama um humano.
#
# Entra pelo MESMO ponto que o AgentReplyService#handoff! (o caminho do
# HANDOFF_MARKER e o da quota estourada): `Ai::AgentReplyService.handoff!`
# marca a flag `ai_agent_handoff` que cala o bot no turno seguinte (ver
# .enabled_for?) e chama o `conversation.bot_handoff!`, que reabre a conversa
# e dispara CONVERSATION_BOT_HANDOFF no barramento — a mesma chamada do
# Chatbots::Nodes::HandoffNode, que fila e notificações já entendem.
#
# Sem bloco duplicado aqui de propósito: as duas pontas do handoff precisam
# dos MESMOS efeitos, e cópia desalinha na primeira mudança. O ponto de
# entrada é idempotente, então tool + HANDOFF_MARKER no mesmo turno emitem um
# evento só.
#
# Sem parâmetro algum: não existe id nem motivo estruturado, só a conversa do
# contexto injetado (ver Ai::ToolRegistry). Não invente propriedade no schema.
#
# ponytail: nada aqui enfileira job dentro do `call`. O savepoint do dry-run
# desfaz banco, não fila — tool que dispare side-effect assíncrono precisa de
# outro desenho.
class Ai::Tools::TransferirParaHumano < Ai::Tool
  SCHEMA = {
    type: 'object',
    properties: {}
  }.freeze

  declare(
    name: 'transferir_para_humano',
    description: <<~DESC.squish,
      Encerra o atendimento automático e chama um atendente humano para
      continuar esta conversa. Chame quando o cliente pedir para falar com uma
      pessoa, quando a dúvida sair do que dá pra resolver por aqui, ou quando
      ele parecer insatisfeito com a automação. Depois de chamar, se despeça —
      esta é a última resposta sua nesta conversa. Só transfere esta conversa.
    DESC
    schema: SCHEMA
  )

  def call(_input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?

    Ai::AgentReplyService.handoff!(conversation)

    'Conversa transferida para a equipe. Avise o cliente que alguém já vai continuar o atendimento por aqui.'
  end
end
