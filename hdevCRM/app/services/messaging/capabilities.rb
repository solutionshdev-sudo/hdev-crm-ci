# Fonte única de verdade sobre risco de banimento e existência de janela de
# mensageria (24h/estilo) por canal. Consumida pelo motor de envio (gate de
# opt-out e SendGateService, Fase 2 do Motor Integrado) — nunca espalhar um
# `if provider == 'baileys'` fora daqui.
#
# Recebe o CHANNEL (o model, ex.: Channel::Whatsapp, Channel::WebWidget), não
# a inbox. Canal desconhecido é tratado como o caso mais seguro: sem risco de
# ban reportado e sem janela de mensageria.
module Messaging::Capabilities
  def self.for(channel)
    case channel
    when Channel::Whatsapp
      whatsapp_capabilities(channel)
    when Channel::Instagram, Channel::FacebookPage
      { ban_risk: false, messaging_window: true }
    else
      { ban_risk: false, messaging_window: false }
    end
  end

  # Baileys é a API não-oficial do WhatsApp (via baileys-service) — único
  # canal com risco real de banimento, e sem janela de mensageria de 24h
  # porque a sessão não tem esse conceito (ver Conversations::MessageWindowService).
  def self.whatsapp_capabilities(channel)
    if channel.provider == 'baileys'
      { ban_risk: true, messaging_window: false }
    else
      { ban_risk: false, messaging_window: true }
    end
  end
  private_class_method :whatsapp_capabilities
end
