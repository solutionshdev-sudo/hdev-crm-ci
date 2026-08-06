# The widget SDK ships under a fixed, unhashed filename (see vite.lib.config.ts)
# because that URL goes inside the snippet customers paste into their own sites.
# `public_file_server.headers` stamps `max-age=1.year` on everything under
# public/, which would freeze an old widget build in every CDN and visitor
# browser until the year runs out. Hashed assets keep the long cache; this one
# entrypoint revalidates instead.
class WidgetSdkCacheControl
  PATH = '/packs/js/sdk.js'.freeze
  CACHE_CONTROL = 'public, max-age=300, must-revalidate'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [status, headers, body] unless env['PATH_INFO'] == PATH

    # Rack 3 wants lowercase field names; drop a capitalized key in case the
    # response still carries one. Copy first so a frozen hash can never break
    # the single file this middleware exists to protect.
    headers = headers.dup
    headers.delete('Cache-Control')
    headers['cache-control'] = CACHE_CONTROL

    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before 0, WidgetSdkCacheControl
