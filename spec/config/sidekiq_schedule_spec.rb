require 'rails_helper'

RSpec.describe 'config/sidekiq.yml schedule' do
  let(:schedule) { YAML.load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result)[:scheduler][:schedule] }

  # Without a zone, Fugit falls back to whatever Rails' Time.zone is.
  it 'names the zone of every cron' do
    schedule.each do |name, job|
      expect(Fugit::Cron.parse(job['cron'])&.timezone&.name).to eq('America/New_York'), "#{name} has no zone"
    end
  end

  it 'points every job at a class that exists' do
    schedule.each_value { |job| expect { job['class'].constantize }.not_to raise_error }
  end
end
