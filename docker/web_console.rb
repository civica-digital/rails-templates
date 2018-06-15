# Settings to support Docker IP bindings

return if Rails.env.production?

Rails.configuration.web_console.whitelisted_ips = '0.0.0.0' if defined?(WebConsole)

BetterErrors::Middleware.allow_ip! '0.0.0.0/0' if defined?(BetterErrors)
