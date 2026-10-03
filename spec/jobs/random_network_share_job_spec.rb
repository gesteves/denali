require 'rails_helper'

RSpec.describe RandomNetworkShareJob, type: :worker do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let!(:entry) { eligible_entry }

  # An entry every network could share, untouched for two years.
  def eligible_entry(**attributes)
    create(:entry, :published, :with_photo, blog: blog, user: user, published_at: 2.years.ago,
           last_shared_on_bluesky_at: 2.years.ago, last_shared_on_mastodon_at: 2.years.ago,
           last_shared_on_instagram_at: 2.years.ago, last_shared_on_threads_at: 2.years.ago, **attributes)
  end

  around do |example|
    # Reservations live in the cache, which the test environment doesn't keep.
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    create(:social_account, :mastodon, user:)
    create(:social_account, :bluesky, user:)
    # Publishing the entries above queued their own shares.
    Sidekiq::Job.clear_all
  end

  def perform(network = 'Mastodon', tags: [], months: 12, excluded: [], immediately: false)
    described_class.new.perform(network, tags, months, excluded, immediately)
  end

  it 'enqueues the share with the caption it checked' do
    perform

    expect(MastodonJob.jobs.map { |job| job['args'] }).to eq([[entry.id, entry.caption_for('Mastodon')]])
  end

  it 'shares at a random moment in the next hour, or now if asked' do
    perform
    expect(MastodonJob.jobs.last['at']).to be_present

    Rails.cache.clear
    MastodonJob.jobs.clear
    perform(immediately: true)
    expect(MastodonJob.jobs.last['at']).to be_nil
  end

  # Until the share is recorded the entry stays among the least shared, so without this the next
  # run could pick it while the first share was still on its way.
  it "doesn't pick an entry it already picked" do
    perform
    perform

    expect(MastodonJob.jobs.size).to eq(1)
  end

  it 'reserves per network' do
    perform('Mastodon')
    perform('Bluesky')

    expect(MastodonJob.jobs.size).to eq(1)
    expect(BlueskyJob.jobs.size).to eq(1)
  end

  it 'gives Bluesky the record key of the moment the post will go out' do
    allow_any_instance_of(described_class).to receive(:rand).with(0..60).and_return(30)
    expect(Bluesky).to receive(:new_tid).with(at: kind_of(Time)).and_call_original

    perform('Bluesky')

    expect(BlueskyJob.jobs.last['args']).to match([entry.id, entry.caption_for('Bluesky'), nil, nil, kind_of(String)])
  end

  it 'shares nothing on a network the user has no account on' do
    perform('Threads')

    expect(ThreadsJob.jobs).to be_empty
  end

  # The stored flag said it fit, but a tag customization has changed the caption since.
  it 'passes over an entry whose caption no longer fits, and records that' do
    entry.update_columns(mastodon_text: 'x' * 500)

    perform

    expect(MastodonJob.jobs).to be_empty
    expect(entry.reload.valid_mastodon_caption).to be false
  end

  it 'tries another entry when the first can’t go out' do
    entry.update_columns(mastodon_text: 'x' * 500)
    fitting = eligible_entry
    Sidekiq::Job.clear_all
    allow_any_instance_of(ActiveRecord::Relation).to receive(:reorder).and_wrap_original do |original, *args|
      # Puts the one that doesn't fit first, as RANDOM() might.
      original.call(Arel.sql("entries.id = #{entry.id} DESC"))
    end

    perform

    expect(MastodonJob.jobs.map { |job| job['args'].first }).to eq([fitting.id])
  end

  it 'logs when there was nothing to share' do
    entry.update_columns(post_to_mastodon: false)
    expect(Sidekiq.logger).to receive(:info).with(/Nothing to share on Mastodon/)

    perform
  end

  it 'filters by tags' do
    perform(tags: ['Wildlife'])
    expect(MastodonJob.jobs).to be_empty

    entry.update!(tag_list: 'Wildlife')
    perform(tags: ['Wildlife'])
    expect(MastodonJob.jobs.size).to eq(1)
  end

  it 'does nothing outside production' do
    allow(Rails.env).to receive(:production?).and_return(false)
    perform
    expect(MastodonJob.jobs).to be_empty
  end
end
