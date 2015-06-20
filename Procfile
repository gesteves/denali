web: bundle exec puma -C config/puma.rb
resque: env TERM_CHILD=1 QUEUE=* bundle exec rake resque:work
