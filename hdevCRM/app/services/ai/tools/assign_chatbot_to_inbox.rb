module Ai
  module Tools
    # Vincula um chatbot às caixas de entrada onde ele deve responder.
    #
    # ChatbotInbox barra dois bots ativos na mesma inbox — o erro volta pro
    # modelo, que explica ao usuário em vez de gravar um conflito.
    class AssignChatbotToInbox < Ai::Tool
      SCHEMA = {
        type: 'object',
        properties: {
          chatbot_id: { type: 'integer', description: 'Id do chatbot.' },
          inbox_ids: {
            type: 'array',
            description: 'Ids das caixas de entrada onde o chatbot deve responder.',
            items: { type: 'integer' }
          }
        },
        required: %w[chatbot_id inbox_ids]
      }.freeze

      declare(
        name: 'vincular_chatbot_a_inbox',
        description: <<~DESC.squish,
          Vincula um chatbot existente a uma ou mais caixas de entrada. Chame quando
          o usuário pedir para ligar, ativar, conectar ou associar um bot a um canal
          (WhatsApp, widget, e-mail). Um chatbot recém-criado nasce como rascunho:
          vincular não o ativa, o usuário ainda precisa ativá-lo no editor.
        DESC
        schema: SCHEMA
      )

      def call(input)
        input = input.to_h.with_indifferent_access
        chatbot = account.chatbots.find_by(id: input[:chatbot_id])
        raise Ai::ToolError, "Chatbot #{input[:chatbot_id]} não existe nesta conta." if chatbot.nil?

        inboxes = account.inboxes.where(id: Array(input[:inbox_ids])).to_a
        raise Ai::ToolError, 'Nenhuma das caixas de entrada informadas existe nesta conta.' if inboxes.empty?

        inboxes.each { |inbox| persist!(chatbot.chatbot_inboxes.find_or_initialize_by(inbox: inbox)) }
        "Chatbot \"#{chatbot.name}\" vinculado a: #{inboxes.map(&:name).join(', ')}."
      end
    end
  end
end
