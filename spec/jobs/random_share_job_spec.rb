require 'rails_helper'

RSpec.describe RandomShareJob, type: :worker do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  def network_jobs
    RandomNetworkShareJob.jobs.map { |job| job['args'] }
  end

  describe '#perform' do
    it 'hands each network its own job, with the schedule’s arguments' do
      described_class.new.perform('Landscapes', %w[Bluesky Mastodon], 12, 'Cherry Blossoms')

      expect(network_jobs).to eq([
        ['Bluesky', ['Landscapes'], 12, ['Cherry Blossoms'], false],
        ['Mastodon', ['Landscapes'], 12, ['Cherry Blossoms'], false]
      ])
    end

    it 'passes share_immediately along' do
      described_class.new.perform('Great Gray Owls', ['Bluesky'], 1, [], true)

      expect(network_jobs).to eq([['Bluesky', ['Great Gray Owls'], 1, [], true]])
    end

    # Its retries would enqueue every network again, including those the failed run had done.
    it "isn't retried" do
      expect(described_class.get_sidekiq_options['retry']).to be false
    end

    it 'skips a network it doesn’t know' do
      described_class.new.perform([], %w[Twitter Mastodon])

      expect(network_jobs.map(&:first)).to eq(['Mastodon'])
    end

    it 'does nothing outside production' do
      allow(Rails.env).to receive(:production?).and_return(false)
      described_class.new.perform([], ['Bluesky'])
      expect(network_jobs).to be_empty
    end

    it 'does nothing without networks' do
      described_class.new.perform([], [])
      expect(network_jobs).to be_empty
    end

    # A new photo was just published, and its own shares take precedence.
    it 'does nothing within an hour of a new entry' do
      create(:entry, :published, blog: blog, user: user, published_at: 30.minutes.ago)
      described_class.new.perform([], ['Bluesky'])
      expect(network_jobs).to be_empty
    end
  end
end
