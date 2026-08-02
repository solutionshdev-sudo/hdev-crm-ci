require 'rails_helper'

# Base::SendOnChannelService é abstrato (channel_class/perform_reply "raise"
# na classe base) — usamos Email::SendOnEmailService como canal concreto pra
# exercitar só o comportamento herdado da base (gate de opt-out/blocked), no
# mesmo estilo de spec/services/email/send_on_email_service_spec.rb. O motor
# anti-ban de janela/warm-up (Messaging::SendGateService) só é acionado pelo
# Whatsapp::SendOnWhatsappService — aqui provamos que ele NÃO vaza pra um
# canal genérico.
describe Base::SendOnChannelService do
  let(:account) { create(:account) }
  let(:email_channel) { create(:channel_email, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: email_channel) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  let(:mailer_context) { instance_double(ConversationReplyMailer) }
  let(:delivery) { instance_double(ActionMailer::MessageDelivery) }
  let(:email_message) { instance_double(Mail::Message) }

  def send_message(message)
    Email::SendOnEmailService.new(message: message).perform
  end

  # A factory de :message faz `sender ||= create(:user, ...)` pra toda mensagem
  # outgoing (spec/factories/messages.rb:37-40) — um `sender: nil` explícito na
  # criação é sobrescrito pelo `||=` do próprio after(:build). O jeito provado
  # de zerar o sender de fato é atualizar DEPOIS de criada (mesmo idioma de
  # spec/lib/integrations/slack/send_on_slack_service_spec.rb:282,
  # `template_message.update!(sender: nil)`).
  def automated_message
    message = create(:message, conversation: conversation, message_type: :outgoing, account: account)
    message.update!(sender: nil)
    message
  end

  def human_message
    create(:message, conversation: conversation, message_type: :outgoing, sender: create(:user, account: account), account: account)
  end

  before do
    allow(ConversationReplyMailer).to receive(:with).with(account: account).and_return(mailer_context)
    allow(mailer_context).to receive(:email_reply).and_return(delivery)
    allow(delivery).to receive(:deliver_now).and_return(email_message)
    allow(email_message).to receive(:message_id).and_return('test-message-id')
    allow(Conversations::ActivityMessageJob).to receive(:perform_later)
  end

  describe '#perform' do
    context 'when the contact opted out of automation and the message is automated' do
      let(:contact) { create(:contact, account: account, automation_opted_out: true) }

      it 'retains the message instead of sending it' do
        message = automated_message
        send_message(message)

        expect(mailer_context).not_to have_received(:email_reply)
        expect(message.reload.status).to eq('failed')
      end

      it 'creates an opt-out activity note' do
        send_message(automated_message)

        expect(Conversations::ActivityMessageJob).to have_received(:perform_later).with(
          conversation, hash_including(content: I18n.t('conversations.activity.opt_out.message_not_sent'))
        )
      end
    end

    context 'when the contact opted out of automation but the message is from a human agent' do
      let(:contact) { create(:contact, account: account, automation_opted_out: true) }

      it 'sends the message normally' do
        message = human_message
        send_message(message)

        expect(mailer_context).to have_received(:email_reply).with(message)
      end
    end

    context 'when the contact is blocked (global mute) and the message is automated' do
      let(:contact) { create(:contact, account: account, blocked: true) }

      it 'retains the message the same way opt-out does' do
        message = automated_message
        send_message(message)

        expect(mailer_context).not_to have_received(:email_reply)
        expect(message.reload.status).to eq('failed')
      end
    end

    context 'when the contact is blocked but the message is from a human agent' do
      let(:contact) { create(:contact, account: account, blocked: true) }

      it 'sends the message normally' do
        message = human_message
        send_message(message)

        expect(mailer_context).to have_received(:email_reply).with(message)
      end
    end

    context 'when the contact is neither opted out nor blocked' do
      it 'sends an automated message normally' do
        message = automated_message
        send_message(message)

        expect(mailer_context).to have_received(:email_reply).with(message)
      end
    end

    context 'when sending through a generic (non-WhatsApp) channel' do
      it 'never consults Messaging::SendGateService — the anti-ban window/warm-up gate is WhatsApp-only' do
        allow(Messaging::SendGateService).to receive(:new)
        message = automated_message

        send_message(message)

        expect(Messaging::SendGateService).not_to have_received(:new)
      end
    end
  end
end
