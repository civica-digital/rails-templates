CarrierWave.configure do |config|
  config.storage = :file
  config.ignore_integrity_errors = false
  config.ignore_processing_errors = false
  config.ignore_download_errors = false

  return unless Rails.env.production? && ENV.key?('AWS_S3_BUCKET')

  config.ignore_integrity_errors = true
  config.ignore_processing_errors = true
  config.ignore_download_errors = true

  config.fog_public = false
  config.fog_attributes = { 'Cache-Control' => "max-age=#{365.days.to_i}" }
  config.fog_provider = 'fog/aws'
  config.fog_directory = ENV.fetch('AWS_S3_BUCKET')
  config.fog_credentials = {
    provider:              'AWS',
    aws_access_key_id:     ENV['AWS_S3_ACCESS_KEY'] || ENV.fetch('AWS_ACCESS_KEY'),
    aws_secret_access_key: ENV['AWS_S3_SECRET_KEY'] || ENV.fetch('AWS_SECRET_KEY'),
    region:                ENV['AWS_S3_REGION'] || ENV['AWS_REGION'] || 'us-east-1',
    endpoint:              ENV.fetch('AWS_S3_HOST') { nil },
    path_style:            true,
  }
  config.storage = :fog
end
