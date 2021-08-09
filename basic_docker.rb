ruby_ver = ask("Ruby version ?")
pg_ver = ask("PostgreSQL version?")
redis_ver = ask("Redis version?")

ruby_ver = '3.0.0' unless ruby_ver.present?
pg_ver = '13' unless pg_ver.present?
redis_ver = '6' unless redis_ver.present?


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
FROM ruby:#{ruby_ver}

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
      - ./config/master.key:/var/app/config/credentials/development.key
      - ./config/credentials.yml.enc:/var/app/config/credentials/development.yml.enc
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
      - ./config/master.key:/var/app/config/credentials/test.key
      - ./config/credentials.yml.enc:/var/app/config/credentials/test.yml.enc
    depends_on:
      - db
      - redis

  db:
    image: postgres:#{pg_ver}
    volumes:
      - #{app_name}-db:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: localdev

  redis:
    image: redis:#{redis_ver}

volumes:
  #{app_name}-db:
CODE

git add: "."
git commit: %Q{ -m 'Docker setup' }