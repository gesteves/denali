# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Threads per worker. For IO-bound apps, more threads help throughput.
# For small containers (512MB), 5 threads is a good balance.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Port to listen on
port ENV.fetch("PORT", 3000)

# Workers (cluster mode). Set WEB_CONCURRENCY=0 for single mode (recommended for <1GB RAM)
# Single mode: 1 process, less memory overhead
# Cluster mode: master + N workers, better for multi-core / larger containers
workers ENV.fetch("WEB_CONCURRENCY", 0)

# Preload app for faster worker boot (only in cluster mode)
preload_app! if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 0

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
