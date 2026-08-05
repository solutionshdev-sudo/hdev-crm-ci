# Expira sessões abandonadas: segue a aresta `timeout` do nó atual quando
# existe; senão aborta e devolve a conversa pra fila humana.
class Chatbots::TimeoutSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ChatbotSession.active.where(expires_at: ..Time.current).find_each(batch_size: 100) do |session|
      handle_timeout(session)
    rescue StandardError => e
      Rails.logger.error("[CHATBOT] timeout sweep failed session=#{session.id}: #{e.message}")
    end
  end

  private

  def handle_timeout(session)
    session.with_lock do
      next unless session.active? && session.expires_at&.past?

      node = session.chatbot.find_node(session.current_node_id)
      session.log_event(:timed_out, node: node)
      timeout_target = node && session.chatbot.next_node_id(node['id'], 'timeout')

      if timeout_target
        session.update!(status: :running, current_node_id: timeout_target, expires_at: nil)
      else
        session.update!(status: :aborted, expires_at: nil)
        session.conversation.bot_handoff!
      end
    end
    Chatbots::RunnerJob.perform_later(session.id) if session.reload.running?
  end
end
