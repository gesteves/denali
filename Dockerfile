# Use the official Ruby image from Docker Hub
FROM ruby:2.6.8

# Set environment variables for Rails
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      libpq-dev \
      nodejs \
      postgresql-client \
      imagemagick \
      git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up the Rails app directory
RUN mkdir /app
WORKDIR /app

# Install Rails dependencies
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.4.22 && bundle install --jobs 20 --retry 5

# Copy the rest of the application code
COPY . .

# Expose port 3000 to the Docker host, so we can access it
EXPOSE 3000

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
