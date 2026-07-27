# Retoma o fluxo após um nó de delay. status + current_node_id (re-checados
# sob lock) conferem se o cliente não respondeu/avançou nesse meio tempo.
# _lock_version ignorado: era capturado antes do save! que o incrementa, então
# nunca batia e o delay jamais retomava. Default nil mantém compat com jobs
# de 3 args já enfileirados.
class Chatbots::ResumeJob < ApplicationJob
  queue_as :medium

  def perform(session_id, node_id, _lock_version = nil)
    session = ChatbotSession.find_by(id: session_id)
    return if session.blank? || !session.waiting_delay?
    return if session.current_node_id != node_id

    session.with_lock do
      next unless session.waiting_delay? && session.current_node_id == node_id

      next_id = session.chatbot.next_node_id(node_id)
      if next_id.blank?
        session.update!(status: :completed, expires_at: nil)
        next
      end
      session.update!(status: :running, current_node_id: next_id, expires_at: nil)
    end
    Chatbots::RunnerJob.perform_later(session.id) if session.reload.running?
  end
end
