gem_group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'database_cleaner-active_record'
  gem 'shoulda-matchers'
end

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

file '.dockerignore', <<-CODE
.git
.gitignore
.gitattributes
Dockerfile
docker-compose.yml
README.md
/.bundle
/log/*
/tmp/*
!/log/.keep
!/tmp/.keep
/tmp/pids/*
!/tmp/pids/
!/tmp/pids/.keep
/storage/*
!/storage/.keep
.byebug_history
.idea/
/config/credentials/*
!/config/credentials/.keep
/public/*
!/public/robots.txt
CODE

file 'Dockerfile', <<-CODE
FROM ruby:<ruby-version>

RUN apt-get update -qq && apt-get install -y postgresql-client

WORKDIR /var/app
COPY Gemfile /var/app/Gemfile
COPY Gemfile.lock /var/app/Gemfile.lock
RUN bundle install
COPY . /var/app

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
CODE

file 'entrypoint.sh', <<-CODE
#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /var/app/tmp/pids/server.pid

bundle exec rails db:create
bundle exec rails db:migrate

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
CODE

file 'docker-compose.yml', <<-CODE
version: "3.9"
services:
  dev:
    build: .
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec rails s -p 3000 -b '0.0.0.0'"
    tty: true
    stdin_open: true
    environment:
      TERM: xterm-256color
      RAILS_ENV: development
      REDIS_URL: redis://redis:6379/0
    volumes:
      - .:/var/app
      - ./config/credentials/development.key:/var/app/config/credentials/development.key
      - ./config/credentials/development.yml.enc:/var/app/config/credentials/development.yml.enc
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis

  test:
    build: .
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec rspec -f d"
    tty: true
    stdin_open: true
    environment:
      TERM: xterm-256color
      RAILS_ENV: test
      REDIS_URL: redis://redis:6379/0
    volumes:
      - .:/var/app
      - ./config/credentials/test.key:/var/app/config/credentials/test.key
      - ./config/credentials/test.yml.enc:/var/app/config/credentials/test.yml.enc
    depends_on:
      - db
      - redis

  db:
    image: postgres:13
    volumes:
      - #{app_name}-db:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: localdev

  redis:
    image: redis:6

volumes:
  #{app_name}-db:
CODE

after_bundle do
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

  inject_into_file 'spec/rails_helper.rb', after: 'RSpec.configure' do
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

  git :init
  git add: "."
  git commit: %Q{ -m 'base app' }
  git branch: %Q{ -M main }
end