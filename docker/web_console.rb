# Settings to support Docker IP bindings

Rails.configuration.web_console.whitelisted_ips = '0.0.0.0'

BetterErrors::Middleware.allow_ip! '0.0.0.0/0' if defined?(BetterErrors)
