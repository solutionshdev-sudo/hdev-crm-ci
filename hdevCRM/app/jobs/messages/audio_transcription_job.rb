class Messages::AudioTranscriptionJob < ApplicationJob
  queue_as :low

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.blank?

    Messages::AudioTranscriptionService.new(attachment: attachment).perform
  end
end
