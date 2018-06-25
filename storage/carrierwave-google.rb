CarrierWave.configure do |config|
  config.storage = :file
  config.ignore_integrity_errors = false
  config.ignore_processing_errors = false
  config.ignore_download_errors = false

  return unless Rails.env.production? && ENV.key?('GOOGLE_STORAGE_BUCKET')

  config.ignore_integrity_errors = true
  config.ignore_processing_errors = true
  config.ignore_download_errors = true

  config.fog_public = false
  config.fog_attributes = { 'Cache-Control' => "max-age=#{365.days.to_i}" }
  config.fog_provider = 'fog/google'
  config.fog_directory = ENV.fetch('GOOGLE_STORAGE_BUCKET')
  config.fog_credentials = {
    provider:                         'Google',
    google_storage_access_key_id:     ENV.fetch('GOOGLE_STORAGE_ACCESS_KEY'),
    google_storage_secret_access_key: ENV.fetch('GOOGLE_STORAGE_SECRET_KEY'),
  }
  config.storage = :fog
end
