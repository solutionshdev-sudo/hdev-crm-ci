# Encerra o atendimento automático DESTA conversa e chama um humano.
#
# Mesma chamada que Chatbots::Nodes::HandoffNode#execute já usa:
# `conversation.bot_handoff!` reabre a conversa e dispara
# CONVERSATION_BOT_HANDOFF no barramento (app/models/conversation.rb:176) —
# o resto do sistema (fila, notificações) já entende esse evento.
#
# NÃO mexe em `conversation.custom_attributes['ai_agent_handoff']` nem inventa
# mecanismo de parada no ToolLoop: silenciar o agente depois do handoff e
# alinhar esse caminho com o outro (AgentReplyService#handoff!) é da próxima
# task, que vê os dois lados.
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

    conversation.bot_handoff!

    'Conversa transferida para a equipe. Avise o cliente que alguém já vai continuar o atendimento por aqui.'
  end
end
