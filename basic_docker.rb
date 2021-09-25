ruby_ver = ask("Ruby version?")
pg_ver = ask("PostgreSQL version?")
redis_ver = ask("Redis version?")

abort 'Ruby version is required' unless ruby_ver.present?
abort 'PostgreSQL version is required' unless pg_ver.present?
abort 'Redis version is required' unless redis_ver.present?

gem_group :development, :test do
  gem 'debase'
  gem 'ruby-debug-ide'
end

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
/public/*
!/public/robots.txt
CODE

file 'Dockerfile', <<-CODE
FROM ruby:#{ruby_ver}

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt-get update && \
    apt-get install postgresql-client nano nodejs -y && \
    npm install --global yarn

WORKDIR /var/app
COPY Gemfile /var/app/Gemfile
COPY Gemfile.lock /var/app/Gemfile.lock
RUN bundle install
COPY . /var/app
RUN yarn install

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
    image: #{app_name}-app
    command: tail -f /dev/null
    volumes:
      - .:/var/app
      - /var/app/node_modules
    ports:
      - "3000:3000"
      - "1234:1234"
      - "26166:26168"
    depends_on:
      - db
      - redis

  db:
    image: postgres:#{pg_ver}
    volumes:
      - #{app_name}-db:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: #{app_name}
      POSTGRES_PASSWORD: localdev

  redis:
    image: redis:#{redis_ver}

volumes:
  #{app_name}-db:
CODE

git add: "."
git commit: %Q{ -m 'Docker setup' }