# Decisão pura do motor anti-ban da Fase 2 (plano §2.3): NÃO envia mensagem,
# NÃO grava nada (nem incrementa o contador — isso é do enforcement, no ponto
# de envio real). Só decide, a partir de `{ channel:, contact:, automated:, now: }`,
# uma de três coisas: `ALLOW` (:allow), `{ postpone_until:, reason: }` ou
# `{ deny: reason }`.
#
# Ordem fixa (não reordenar): opt-out -> janela de horário -> warm-up (idade do
# pareamento) -> cap diário. Janela e warm-up só armam quando `automated: true`
# (humano nunca é bloqueado por elas); o cap diário protege o número como um
# todo e vale pra qualquer remetente. Janela/warm-up/cap só armam em canais com
# `ban_risk: true` (Messaging::Capabilities) — opt-out vale em qualquer canal.
class Messaging::SendGateService
  ALLOW = :allow

  WINDOW_START_HOUR = 7
  WINDOW_END_HOUR = 22
  DEFAULT_DAILY_CAP = 300

  # [idade mínima em dias, teto de mensagens/dia] — ordenado do mais novo pro
  # mais antigo; o primeiro cujo `pairing_age_days` bate vence. Float::INFINITY
  # aos 31 dias = sem teto de warm-up (só o cap diário continua valendo).
  WARM_UP_SCHEDULE = [
    [31, Float::INFINITY],
    [15, 200],
    [8, 100],
    [4, 50],
    [0, 20]
  ].freeze

  pattr_initialize [:channel!, :contact!, :automated!, :now!]

  def call
    return deny(:opted_out) if opted_out?
    return ALLOW unless ban_risk?
    return postpone(:outside_window, next_window_start) if automated && outside_window?
    return postpone(:warm_up_limit, next_window_start(skip_today: true)) if automated && warm_up_exceeded?
    return postpone(:daily_cap, next_window_start(skip_today: true)) if daily_cap_exceeded?

    ALLOW
  end

  private

  # Reusa a MESMA semântica do gate de `Base::SendOnChannelService`
  # (automation_opted_out? OU blocked?) — quem calcula `automated` é o
  # `automated_message?` de lá; aqui só combina com o opt-out do contato.
  def opted_out?
    automated && (contact.automation_opted_out? || contact.blocked?)
  end

  def ban_risk?
    Messaging::Capabilities.for(channel)[:ban_risk]
  end

  def local_now
    @local_now ||= now.in_time_zone(channel.messaging_timezone)
  end

  def outside_window?
    hour = local_now.hour
    hour < WINDOW_START_HOUR || hour >= WINDOW_END_HOUR
  end

  def warm_up_exceeded?
    today_count >= warm_up_limit
  end

  def daily_cap_exceeded?
    today_count >= daily_cap
  end

  def today_count
    @today_count ||= Messaging::BaileysSendCounter.new(channel: channel).count(now: now)
  end

  def daily_cap
    configured = channel.provider_config['daily_send_cap']
    configured.present? ? configured.to_i : DEFAULT_DAILY_CAP
  end

  def warm_up_limit
    WARM_UP_SCHEDULE.find { |min_age, _limit| pairing_age_days >= min_age }.last
  end

  def pairing_age_days
    return 0 if paired_at.blank?

    ((now - paired_at) / 1.day).floor
  end

  def paired_at
    raw = channel.provider_config['paired_at']
    Time.zone.parse(raw) if raw.present?
  end

  # Próxima abertura da janela (7h local). `skip_today: true` pula direto pro
  # dia seguinte — usado quando o motivo é "orçamento do dia estourado"
  # (warm-up/cap diário): o contador só reseta na virada do dia, então mesmo
  # que ainda faltem horas pro fim da janela de hoje, não adianta reabrir mais
  # cedo.
  def next_window_start(skip_today: false)
    candidate = local_now.change(hour: WINDOW_START_HOUR, min: 0, sec: 0)
    candidate += 1.day if skip_today || candidate <= local_now
    candidate
  end

  def deny(reason)
    { deny: reason }
  end

  def postpone(reason, postpone_until)
    { postpone_until: postpone_until, reason: reason }
  end
end
