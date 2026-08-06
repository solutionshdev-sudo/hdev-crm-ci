class ChatbotInbox < ApplicationRecord
  belongs_to :chatbot
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :chatbot_id }
  validate :single_active_chatbot_per_inbox

  private

  # Dois bots ativos na mesma inbox responderiam juntos — barrar no vínculo.
  def single_active_chatbot_per_inbox
    return unless chatbot&.active?

    conflict = ChatbotInbox.where(inbox_id: inbox_id)
                           .where.not(chatbot_id: chatbot_id)
                           .joins(:chatbot)
                           .exists?(chatbots: { status: :active })
    errors.add(:inbox_id, I18n.t('errors.models.chatbot_inbox.active_chatbot_exists')) if conflict
  end
end
