module Ai
  module Tools
    # Cria etiquetas (labels) de conversa.
    #
    # O model Label já derruba título com espaço, duplicado e caractere inválido
    # — o erro volta pro modelo em vez de virar exceção.
    class CreateLabels < Ai::Tool
      SCHEMA = {
        type: 'object',
        properties: {
          labels: {
            type: 'array',
            description: 'Etiquetas a criar.',
            items: {
              type: 'object',
              properties: {
                title: {
                  type: 'string',
                  description: 'Nome sem espaço nem acento de pontuação — use hífen ou underline (ex: "cliente-vip").'
                },
                description: { type: 'string' },
                color: { type: 'string', description: 'Cor hexadecimal, ex: "#00875A".' },
                show_on_sidebar: { type: 'boolean', description: 'Fixar na barra lateral. Padrão: true.' }
              },
              required: %w[title]
            }
          }
        },
        required: %w[labels]
      }.freeze

      declare(
        name: 'criar_etiquetas',
        description: <<~DESC.squish,
          Cria etiquetas (labels/tags) para classificar conversas. Chame quando o
          usuário pedir para criar etiquetas, tags, marcadores ou categorias de
          atendimento. Crie todas de uma vez numa única chamada.
        DESC
        schema: SCHEMA
      )

      def call(input)
        list = Array(input.to_h.with_indifferent_access[:labels])
        raise Ai::ToolError, 'Informe ao menos uma etiqueta.' if list.empty?

        labels = list.map { |label| persist!(build(label)) }
        "Etiquetas criadas: #{labels.map(&:title).join(', ')}."
      end

      private

      def build(label)
        label = label.to_h.with_indifferent_access
        account.labels.new(
          title: label[:title],
          description: label[:description],
          color: label[:color].presence || '#1f93ff',
          show_on_sidebar: label.fetch(:show_on_sidebar, true)
        )
      end
    end
  end
end
