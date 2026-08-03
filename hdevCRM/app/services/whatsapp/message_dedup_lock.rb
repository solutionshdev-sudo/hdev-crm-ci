# Atomic dedup lock for WhatsApp incoming messages.
#
# Meta can deliver the same webhook event multiple times. This lock uses
# Redis SET NX EX to ensure only one worker processes a given source_id.
class Whatsapp::MessageDedupLock
  KEY_PREFIX = Redis::RedisKeys::MESSAGE_SOURCE_KEY
  DEFAULT_TTL = 1.day.to_i

  def initialize(source_id, ttl: DEFAULT_TTL)
    @key = format(KEY_PREFIX, id: source_id)
    @ttl = ttl
  end

  # Returns true when the lock is acquired (caller should proceed).
  # Returns false when another worker already holds the lock.
  def acquire!
    result = ::Redis::Alfred.set(@key, true, nx: true, ex: @ttl)
    # DEBUG temporário: quem toca o lock do spec 'appends'?
    if @key == 'MESSAGE_SOURCE_KEY::SDFADSf23sfasdafasdfa'
      warn "DEBUG-LOCK acquire result=#{result.inspect} at=#{Process.clock_gettime(Process::CLOCK_MONOTONIC).round(2)}\n#{caller.first(6).join("\n")}"
    end
    result
  end
end
