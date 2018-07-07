Rails.configuration.generators do |g|
  g.orm                  :active_record
  g.template_engine      :haml
  g.test_framework       :rspec, fixture: false, views: false
  g.form_builder         :simple_form
  g.fixture_replacement  :factory_bot, dir: 'spec/factories'
  g.stylesheets          false
  g.javascripts          false
  g.helper               false
  g.assets               false
  g.jbuilder             false
end
