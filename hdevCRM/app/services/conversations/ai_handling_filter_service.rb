# Aba "IA" (plano §3b.2): aproximação barata e indexável do predicado fino
# `Conversation#ai_handling?` (que é a verdade por conversa, exibida no
# badge). Aqui só o lado SARGÁVEL entra em SQL — de propósito NÃO filtra
# inbox allowlist nem opt-out/bloqueio do contato (isso é Ruby puro dentro de
# `Ai::AgentReplyService.enabled_for?`, não vira condição de índice), o que
# pode incluir conversas que o badge não marcaria. É a divergência aceita
# pelo plano: filtro de lista é aproximação, badge (campo `ai_handling`) é a
# verdade fina.
class Conversations::AiHandlingFilterService
  attr_reader :conversations, :account

  def initialize(conversations, account)
    @conversations = conversations
    @account = account
  end

  # Os dois lados nascem da MESMA `conversations` recebida, só o WHERE muda —
  # é o que mantém as duas pontas estruturalmente compatíveis pro `.or`
  # (mesmos joins/includes), sem precisar de subselects.
  def perform
    session_conversations.or(agent_eligible_conversations)
  end

  private

  def session_conversations
    conversations.where(id: ChatbotSession.active.select(:conversation_id))
  end

  # Reproduz em SQL só os predicados sargáveis de
  # `Ai::AgentReplyService.enabled_for?`: conta com o agente ligado, conversa
  # não resolvida, sem assignee e sem handoff marcado. `ai_agent_enabled` é
  # decisão POR CONTA — se a conta atual não tem o agente ligado, o lado
  # agente do filtro é vazio (usa `where(id: [])` em vez de `.none` pra
  # continuar estruturalmente compatível com o `.or` acima).
  def agent_eligible_conversations
    return conversations.where(id: []) unless agent_enabled?

    conversations.where.not(status: :resolved)
                 .where(assignee_id: nil)
                 .where("(conversations.custom_attributes->>'ai_agent_handoff') IS DISTINCT FROM 'true'")
  end

  def agent_enabled?
    Ai::AgentReplyService.truthy?(account.custom_attributes['ai_agent_enabled'])
  end
end

Conversations::AiHandlingFilterService.prepend_mod_with('Conversations::AiHandlingFilterService')
