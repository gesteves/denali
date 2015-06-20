web: bundle exec puma -C config/puma.rb
worker: env TERM_CHILD=1 QUEUE=* bundle exec rake resque:work
