FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client \
      cron && \
    rm -rf /var/lib/apt/lists/*

COPY crontab /etc/cron.d/inclusion-sync
RUN chmod 0644 /etc/cron.d/inclusion-sync && crontab /etc/cron.d/inclusion-sync

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

RUN chmod +x entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
