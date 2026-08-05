class AdministratorNotifications::ChannelNotificationsMailer < AdministratorNotifications::BaseMailer
  def facebook_disconnect(inbox)
    subject = I18n.t('mailers.channel_notifications_mailer.facebook_disconnect.subject')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def instagram_disconnect(inbox)
    subject = I18n.t('mailers.channel_notifications_mailer.instagram_disconnect.subject')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def tiktok_disconnect(inbox)
    subject = I18n.t('mailers.channel_notifications_mailer.tiktok_disconnect.subject')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def whatsapp_disconnect(inbox)
    subject = I18n.t('mailers.channel_notifications_mailer.whatsapp_disconnect.subject')
    send_notification(subject, action_url: inbox_url(inbox))
  end

  def email_disconnect(inbox)
    subject = I18n.t('mailers.channel_notifications_mailer.email_disconnect.subject')
    send_notification(subject, action_url: inbox_url(inbox))
  end
end
