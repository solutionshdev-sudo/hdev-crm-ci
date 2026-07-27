class SuperAdmin::InstanceStatusesController < SuperAdmin::ApplicationController
  def show
    @metrics = {}
    app_version
    sha
    postgres_status
    redis_metrics
    instance_meta
  end

  def instance_meta
    @metrics['Migrações do banco'] = ActiveRecord::Base.connection.migration_context.needs_migration? ? 'pendentes' : 'completas'
  end

  def app_version
    @metrics['Versão do Hdev CRM'] = Chatwoot.config[:version]
  end

  def sha
    @metrics['Git SHA'] = GIT_HASH
  end

  def postgres_status
    @metrics['Postgres ativo'] = if ActiveRecord::Base.connection.active?
                                   'sim'
                                 else
                                   'não'
                                 end
  end

  def redis_metrics
    r = Redis.new(Redis::Config.app)
    if r.ping == 'PONG'
      redis_server = r.info
      @metrics['Redis ativo'] = 'sim'
      @metrics['Versão do Redis'] = redis_server['redis_version']
      @metrics['Redis: clientes conectados'] = redis_server['connected_clients']
      @metrics["Redis: configuração 'maxclients'"] = redis_server['maxclients']
      @metrics['Redis: memória usada'] = redis_server['used_memory_human']
      @metrics['Redis: pico de memória'] = redis_server['used_memory_peak_human']
      @metrics['Redis: memória total disponível'] = redis_server['total_system_memory_human']
      @metrics["Redis: configuração 'maxmemory'"] = redis_server['maxmemory']
      @metrics["Redis: configuração 'maxmemory_policy'"] = redis_server['maxmemory_policy']
    end
  rescue Redis::CannotConnectError
    @metrics['Redis ativo'] = 'não'
  end
end
