gem_group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'database_cleaner-active_record'
  gem 'shoulda-matchers'
end

run 'bundle install'

initializer 'generators.rb', <<-CODE

Rails.application.config.generators do |g|
  g.test_framework :rspec,
    fixtures: true,
    view_specs: false,
    helper_specs: false,
    routing_specs: false,
    controller_specs: false,
    request_specs: true
  g.fixture_replacement :factory_bot, suffix_factory: 'factory'
end

CODE

generate 'rspec:install'

inject_into_file 'spec/rails_helper.rb', before: 'RSpec.configure' do
<<-CODE

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

CODE
end

inject_into_file 'spec/rails_helper.rb', after: 'RSpec.configure do |config|' do
<<-CODE


  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end
  
  config.append_after do
    DatabaseCleaner.clean
  end
  
  config.include FactoryBot::Syntax::Methods

CODE
end

git add: "."
git commit: %Q{ -m 'RSpec setup' }