# Contador diário de envios por instância baileys (Motor Fase 2, plano §2.3).
# Redis::Alfred, mesmo padrão do AccountEmailRateLimitable#increment_email_sent_count:
# INCR e só seta expire na primeira incrementação do dia (o TTL de 48h dá folga
# pro Messaging::SendGateService nunca ler um contador zerado por corrida de fuso
# no fechamento do dia). A data usada na chave é o dia local da conta
# (Channel::Whatsapp#messaging_timezone) — o mesmo fuso que arma a janela 7h-22h.
#
# Só chama record_send! quando o envio de fato sai (allow) — nunca em postpone/deny;
# quem decide isso é o enforcement em Whatsapp::SendOnWhatsappService, não aqui.
#
# Nome (record_send!, não increment!): Rails/SkipsModelValidations bate no NOME do método em
# qualquer receiver, não só em ActiveRecord — increment! aqui é Redis puro, sem validação nenhuma
# pra pular, mas o cop não sabe disso.
class Messaging::BaileysSendCounter
  EXPIRY = 48.hours.to_i

  pattr_initialize [:channel!]

  def count(now: Time.current)
    Redis::Alfred.get(key_for(now)).to_i
  end

  def record_send!(now: Time.current)
    key = key_for(now)
    Redis::Alfred.incr(key).tap do |total|
      Redis::Alfred.expire(key, EXPIRY) if total == 1
    end
  end

  private

  def key_for(now)
    format(Redis::RedisKeys::BAILEYS_DAILY_SENT_COUNT, instance_id: instance_id, date: local_date(now))
  end

  def instance_id
    channel.provider_config['instance_id']
  end

  def local_date(now)
    now.in_time_zone(channel.messaging_timezone).strftime('%Y%m%d')
  end
end
