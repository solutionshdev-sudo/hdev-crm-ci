module Ai
  module Tools
    # Gera um fluxo de chatbot a partir de linguagem natural.
    #
    # A rede de segurança é o Chatbots::FlowValidator, que já roda em toda
    # gravação: start único, ids únicos, tipo conhecido, aresta órfã e ciclo sem
    # nó de espera. Por isso o schema aqui não replica a validação — trava o que
    # é enum (`type`) e deixa `data` livre, devolvendo os erros do validator pro
    # modelo corrigir sozinho na próxima iteração.
    class CreateChatbotFlow < Ai::Tool
      # Cascata vertical simples: o Vue Flow precisa de posição, e o modelo não
      # deve gastar tokens fazendo layout. O usuário arrasta depois.
      NODE_SPACING_Y = 140
      NODE_X = 240

      # Espelha nodeTypes.js (data default e handles) e os nós do motor em
      # Chatbots::Nodes::*. Divergir daqui gera fluxo que salva mas não roda.
      NODE_DATA_REFERENCE = <<~REF.freeze
        Campos de `data` por tipo de nó:
        - start: {}
        - message: content
        - question: content; input_type ("buttons" ou "free_text"); options [{id, title}];
          save_as; invalid_message; max_retries
        - condition: mode ("all"|"any"); rules [{left, operator, right}]. Operadores:
          equals, not_equals, contains, not_contains, starts_with, greater_than,
          less_than, is_present, is_blank, matches_regex
        - collect: content; validation ("none"|"email"|"phone"|"number"|"date"|"cpf"|
          "cnpj"|"regex"); regex; map_to ("contact.name"|"contact.email"|
          "contact.phone_number"|"contact.custom_attributes.CHAVE"); save_as;
          invalid_message; max_retries
        - delay: seconds
        - handoff: message; note; assign_to ("none"|"team"|"agent"); team_id; agent_id
        - tag: add [nomes de labels]; remove [nomes de labels]
        - webhook: method ("get"|"post"); url; headers; body_template; save_as
        - ai: prompt; send_reply (booleano); save_as
        - deal: pipeline_id; stage_id; title_template; value_template
        - end: message; resolve_conversation (booleano)

        `sourceHandle` da aresta, por tipo de nó de ORIGEM:
        - start, message, delay, tag, deal: omita (saída única)
        - condition: "true" e "false"
        - question com input_type "buttons": um handle por opção, usando o `id` da
          opção; mais "fallback" (resposta não reconhecida) e "timeout"
        - question com input_type "free_text": "out" e "timeout"
        - collect: "out", "fallback" e "timeout"
        - webhook: "out" (sucesso) e "error"
        - ai: "out" e "handoff"
        - handoff e end: terminais, sem saída

        Interpolação com {{...}} em qualquer texto. A lista é fechada — variável
        fora dela renderiza vazio: contact.name, contact.email,
        contact.phone_number, contact.custom_attributes.CHAVE, conversation.id,
        inbox.name, account.name, now, e vars.NOME para o que foi gravado por save_as.
      REF

      SCHEMA = {
        type: 'object',
        properties: {
          name: {
            type: 'string',
            description: 'Nome curto e descritivo do fluxo, em português.'
          },
          nodes: {
            type: 'array',
            description: 'Nós do fluxo. Exatamente um nó do tipo "start" é obrigatório.',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string', description: 'Identificador único dentro do fluxo.' },
                type: { type: 'string', enum: Chatbots::FlowValidator::NODE_TYPES },
                data: { type: 'object', description: NODE_DATA_REFERENCE }
              },
              required: %w[id type]
            }
          },
          edges: {
            type: 'array',
            description: 'Ligações entre os nós.',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string' },
                source: { type: 'string', description: 'id do nó de origem' },
                target: { type: 'string', description: 'id do nó de destino' },
                sourceHandle: { type: 'string', description: 'Saída nomeada; ver referência em data.' }
              },
              required: %w[id source target]
            }
          }
        },
        required: %w[name nodes edges]
      }.freeze

      declare(
        name: 'criar_fluxo_chatbot',
        description: <<~DESC.squish,
          Cria um fluxo de chatbot novo, salvo como RASCUNHO para o usuário revisar e
          ativar no editor visual. Chame sempre que o usuário pedir para criar, montar,
          gerar ou desenhar um fluxo, bot, funil de atendimento ou automação de conversa.
          Todo caminho do fluxo precisa terminar em um nó "end" ou "handoff" — nunca
          deixe o cliente sem saída.
        DESC
        schema: SCHEMA
        # strict fica desligado: `data` é objeto livre e o modo estrito exige
        # additionalProperties: false em todo objeto do schema.
      )

      def call(input)
        input = input.to_h.with_indifferent_access
        chatbot = build(input)

        raise Ai::ToolError, "Fluxo inválido: #{chatbot.errors.full_messages.join('; ')}" unless chatbot.save

        "Fluxo \"#{chatbot.name}\" criado como rascunho (id #{chatbot.id}) com " \
          "#{chatbot.flow['nodes'].size} nós. Peça ao usuário para revisar no editor e ativar."
      end

      private

      def build(input)
        account.chatbots.new(
          name: input[:name].presence || 'Fluxo gerado por IA',
          status: :draft,
          created_by: user,
          updated_by: user,
          flow: { 'nodes' => positioned(input[:nodes]), 'edges' => edges(input[:edges]) }
        )
      end

      def positioned(nodes)
        Array(nodes).each_with_index.map do |node, index|
          {
            'id' => node[:id].to_s,
            'type' => node[:type].to_s,
            'data' => (node[:data] || {}).to_h,
            'position' => { 'x' => NODE_X, 'y' => index * NODE_SPACING_Y }
          }
        end
      end

      def edges(list)
        Array(list).map do |edge|
          {
            'id' => edge[:id].to_s,
            'source' => edge[:source].to_s,
            'target' => edge[:target].to_s
          }.tap { |hash| hash['sourceHandle'] = edge[:sourceHandle].to_s if edge[:sourceHandle].present? }
        end
      end
    end
  end
end
