HealthCheck.setup do |config|
  config.uri = 'status'
  config.success = 'ok'
  config.max_age = 1
  config.http_status_for_error_text = 500
  config.http_status_for_error_object = 500
  config.buckets = { ENV['AWS_S3_BUCKET'] => [:R, :W, :D] }
  config.standard_checks = [
    'site',
    'database',
    'migrations',
  ]
end
