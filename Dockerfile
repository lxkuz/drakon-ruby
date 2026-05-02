# test — docker build --target test  |  docker compose run --rm test
FROM ruby:3.2-alpine AS test
WORKDIR /app
COPY Gemfile drakon_ruby.gemspec Rakefile ./
COPY lib/ lib/
COPY test/ test/
RUN bundle install
CMD ["bundle", "exec", "rake", "test"]

# runtime (по умолчанию) — образ CLI без bundler
FROM ruby:3.2-alpine AS runtime
WORKDIR /app
COPY lib/ lib/
COPY exe/drakon2rb exe/drakon2rb
RUN chmod +x exe/drakon2rb
ENTRYPOINT ["ruby", "/app/exe/drakon2rb"]
