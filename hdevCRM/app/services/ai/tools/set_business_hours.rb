module Ai
  module Tools
    # Define o horário de atendimento de uma caixa de entrada.
    #
    # Os sete WorkingHour já nascem com a inbox (OutOfOffisable), então aqui é
    # só edição — grava com persist! em vez do Inbox#update_working_hours, que
    # usa `update` e engole erro de validação em silêncio.
    class SetBusinessHours < Ai::Tool
      SCHEMA = {
        type: 'object',
        properties: {
          inbox_id: { type: 'integer', description: 'Id da caixa de entrada.' },
          enabled: { type: 'boolean', description: 'Ligar o horário de atendimento. Padrão: true.' },
          timezone: { type: 'string', description: 'Fuso horário IANA, ex: "America/Sao_Paulo".' },
          out_of_office_message: { type: 'string', description: 'Resposta automática fora do horário.' },
          days: {
            type: 'array',
            description: 'Dias a alterar. Dia não informado fica como está.',
            items: {
              type: 'object',
              properties: {
                day_of_week: { type: 'integer', description: '0 = domingo, 1 = segunda, ... 6 = sábado.' },
                closed_all_day: { type: 'boolean', description: 'Fechado o dia inteiro.' },
                open_all_day: { type: 'boolean', description: 'Aberto 24h.' },
                open_hour: { type: 'integer', description: 'Hora de abertura, 0 a 23.' },
                open_minutes: { type: 'integer', description: 'Minuto de abertura, 0 a 59.' },
                close_hour: { type: 'integer', description: 'Hora de fechamento, 0 a 23.' },
                close_minutes: { type: 'integer', description: 'Minuto de fechamento, 0 a 59.' }
              },
              required: %w[day_of_week]
            }
          }
        },
        required: %w[inbox_id days]
      }.freeze

      declare(
        name: 'definir_horario_atendimento',
        description: <<~DESC.squish,
          Define o horário de atendimento de uma caixa de entrada e a mensagem
          automática fora do horário. Chame quando o usuário pedir para configurar
          horário comercial, expediente, dias de funcionamento ou resposta fora do
          horário. O fechamento precisa ser depois da abertura no mesmo dia.
        DESC
        schema: SCHEMA
      )

      def call(input)
        input = input.to_h.with_indifferent_access
        inbox = account.inboxes.find_by(id: input[:inbox_id])
        raise Ai::ToolError, "Caixa de entrada #{input[:inbox_id]} não existe nesta conta." if inbox.nil?

        update_inbox(inbox, input)
        Array(input[:days]).each { |day| update_day(inbox, day) }

        open_days = inbox.working_hours.reload.reject(&:closed_all_day?).size
        "Caixa \"#{inbox.name}\": #{open_days} dia(s) aberto(s), fuso #{inbox.timezone}, " \
          "horário de atendimento #{inbox.working_hours_enabled? ? 'ativado' : 'desativado'}."
      end

      private

      def update_inbox(inbox, input)
        inbox.working_hours_enabled = input.fetch(:enabled, true)
        inbox.timezone = input[:timezone] if input[:timezone].present?
        inbox.out_of_office_message = input[:out_of_office_message] if input[:out_of_office_message].present?
        persist!(inbox)
      end

      def update_day(inbox, day)
        day = day.to_h.with_indifferent_access
        record = inbox.working_hours.find_by(day_of_week: day[:day_of_week])
        raise Ai::ToolError, "Dia da semana inválido: #{day[:day_of_week]} (use 0 a 6)." if record.nil?

        record.assign_attributes(day.slice(*Inbox::OFFISABLE_ATTRS))
        persist!(record)
      end
    end
  end
end
