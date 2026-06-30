FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

RUN chmod +x entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
