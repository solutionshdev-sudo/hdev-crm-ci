# The flow engine. One invocation advances the session until it waits for
# input/delay, halts, or hits MAX_STEPS. Serialized by session.with_lock plus
# the per-conversation mutex in Chatbots::RunnerJob — two bursts of customer
# messages can never advance the flow twice.
class Chatbots::ExecutionService
  MAX_STEPS = 50

  # Registry literal — nunca constantize de string vinda do usuário.
  TYPE_MAP = {
    'start' => Chatbots::Nodes::StartNode,
    'message' => Chatbots::Nodes::MessageNode,
    'question' => Chatbots::Nodes::QuestionNode,
    'condition' => Chatbots::Nodes::ConditionNode,
    'collect' => Chatbots::Nodes::CollectNode,
    'delay' => Chatbots::Nodes::DelayNode,
    'handoff' => Chatbots::Nodes::HandoffNode,
    'tag' => Chatbots::Nodes::TagNode,
    'webhook' => Chatbots::Nodes::WebhookNode,
    'ai' => Chatbots::Nodes::AiNode,
    'deal' => Chatbots::Nodes::DealNode,
    'end' => Chatbots::Nodes::EndNode
  }.freeze

  def initialize(session:, message: nil)
    @session = session
    @message = message
  end

  def perform
    @session.with_lock do
      next unless @session.active?

      handle_waiting_input if @session.waiting_input? && @message
      run_loop if @session.running?
      @session.last_activity_at = Time.current
      @session.save!
    end
  rescue StandardError => e
    fail_session(e)
  end

  private

  def handle_waiting_input
    node = current_node
    return fail_and_handoff('current node missing') if node.nil?

    apply(build(node).handle_input(@message), node)
  end

  def run_loop
    MAX_STEPS.times do
      break unless @session.running?

      node = current_node
      return fail_and_handoff('current node missing') if node.nil?

      @session.log_event(:entered, node: node)
      apply(build(node).execute, node)
    end
    # MAX_STEPS sem parar = ciclo que escapou da validação estática
    fail_and_handoff('max steps exceeded') if @session.running?
  end

  def apply(result, node)
    action, arg1, arg2 = result
    case action
    when :continue
      if arg1.blank?
        # nó terminal sem aresta de saída: fluxo termina limpo
        @session.status = :completed
      else
        @session.current_node_id = arg1
      end
      @session.log_event(:completed, node: node)
    when :wait
      @session.status = arg1
      @session.expires_at = arg2
    when :halt
      @session.status = arg1
      @session.expires_at = nil
    end
  end

  def build(node)
    klass = TYPE_MAP.fetch(node['type']) { raise "unknown node type #{node['type']}" }
    klass.new(@session, node)
  end

  def current_node
    @session.chatbot.find_node(@session.current_node_id)
  end

  def fail_session(error)
    Rails.logger.error("[CHATBOT] session=#{@session.id} failed: #{error.class} #{error.message}")
    # Fora do with_lock (que já saiu via exceção): atualização direta e handoff.
    # rubocop:disable Rails/SkipsModelValidations
    @session.update_columns(status: ChatbotSession.statuses[:failed], last_error: error.message.to_s.first(250))
    # rubocop:enable Rails/SkipsModelValidations
    @session.conversation.bot_handoff!
  rescue StandardError => e
    Rails.logger.error("[CHATBOT] session=#{@session.id} failure cleanup failed: #{e.message}")
  end

  def fail_and_handoff(reason)
    @session.status = :failed
    @session.last_error = reason
    @session.save!
    @session.conversation.bot_handoff!
  end
end
