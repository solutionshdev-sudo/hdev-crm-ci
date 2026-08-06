module Ai
  module Tools
    # Cria um funil de vendas com etapas no kanban de Negócios.
    #
    # As validações de DealPipeline/DealStage são a rede de segurança: cor fora
    # do hexadecimal, probabilidade fora de 0..100 e nome vazio voltam pro
    # modelo como tool_result de erro e ele corrige sozinho.
    class CreateDealPipeline < Ai::Tool
      SCHEMA = {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Nome do funil, em português.' },
          stages: {
            type: 'array',
            description: 'Etapas na ordem do funil. Omita para usar as etapas padrão do HDEV CRM.',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                color: { type: 'string', description: 'Cor hexadecimal, ex: "#0EA5E9".' },
                probability: { type: 'integer', description: 'Chance de fechamento, inteiro de 0 a 100.' },
                stage_type: {
                  type: 'string',
                  enum: %w[open won lost],
                  description: '"won" fecha como ganho e "lost" como perdido. O resto é "open".'
                }
              },
              required: %w[name]
            }
          }
        },
        required: %w[name]
      }.freeze

      declare(
        name: 'criar_funil',
        description: <<~DESC.squish,
          Cria um funil de vendas (pipeline) com etapas no kanban de Negócios. Chame
          quando o usuário pedir para criar, montar ou configurar um funil, pipeline,
          esteira ou processo comercial. Todo funil precisa terminar com uma etapa
          "won" e uma "lost" — sem elas o negócio nunca fecha.
        DESC
        schema: SCHEMA
      )

      def call(input)
        input = input.to_h.with_indifferent_access
        pipeline = account.deal_pipelines.new(name: input[:name])
        stages(input).each_with_index { |stage, index| pipeline.deal_stages.new(stage_attributes(stage, index)) }
        persist!(pipeline)

        "Funil \"#{pipeline.name}\" com as etapas: #{pipeline.deal_stages.map(&:name).join(' → ')}."
      end

      private

      def stages(input)
        Array(input[:stages]).presence || DealPipeline::DEFAULT_STAGES
      end

      def stage_attributes(stage, index)
        stage = stage.to_h.with_indifferent_access
        {
          account_id: account.id,
          name: stage[:name],
          color: stage[:color].presence || '#64748B',
          position: index + 1,
          probability: stage[:probability] || 50,
          stage_type: stage[:stage_type].presence || 'open'
        }
      end
    end
  end
end
