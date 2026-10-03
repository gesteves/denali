require 'rails_helper'

RSpec.describe ApplicationJob do
  describe '.retry_delay' do
    it 'backs off exponentially for an unprocessed photo, up to ten minutes' do
      expect(described_class.retry_delay(0, UnprocessedPhotoError.new)).to eq(1)
      expect(described_class.retry_delay(4, UnprocessedPhotoError.new)).to eq(16)
      expect(described_class.retry_delay(20, UnprocessedPhotoError.new)).to eq(10.minutes.to_i)
    end

    # Enough room for a slow analysis, where count + 1 seconds ran out in about half an hour.
    it 'spreads 25 retries for an unprocessed photo over hours' do
      total = (0...25).sum { |count| described_class.retry_delay(count, UnprocessedPhotoError.new) }
      expect(total).to be > 2.hours.to_i
    end

    it 'leaves other errors to Sidekiq' do
      expect(described_class.retry_delay(3, StandardError.new)).to be_nil
    end
  end

  describe 'retry blocks' do
    # A subclass that overrides retry_delay keeps the parent's rules through super;
    # declaring sidekiq_retry_in would have replaced them.
    let(:job_class) do
      Class.new(ApplicationJob) do
        def self.retry_delay(count, exception)
          exception.is_a?(ArgumentError) ? :discard : super
        end
      end
    end

    it 'gives every job a block that asks its own retry_delay' do
      expect(job_class.sidekiq_retry_in_block.call(0, ArgumentError.new)).to eq(:discard)
      expect(job_class.sidekiq_retry_in_block.call(2, UnprocessedPhotoError.new)).to eq(4)
    end

    it 'works for jobs further down the hierarchy' do
      grandchild = Class.new(job_class)
      expect(grandchild.sidekiq_retry_in_block.call(0, ArgumentError.new)).to eq(:discard)
    end
  end

  describe '.enqueue_debounced' do
    # The test environment's null store never reports a key, so the window needs a real store.
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original
    end

    let(:job_class) do
      stub_const('DebouncedJob', Class.new(ApplicationJob) { def perform(*); end })
    end

    it 'runs once per window for the same arguments, after the burst' do
      freeze_time do
        3.times { job_class.enqueue_debounced(1, 'update', window: 30.seconds) }

        expect(job_class.jobs.size).to eq(1)
        expect(job_class.jobs.first['args']).to eq([1, 'update'])
        expect(job_class.jobs.first['at']).to eq(30.seconds.from_now.to_f)
      end
    end

    it 'keeps different arguments apart' do
      job_class.enqueue_debounced(1, window: 30.seconds)
      job_class.enqueue_debounced(2, window: 30.seconds)

      expect(job_class.jobs.map { |job| job['args'] }).to eq([[1], [2]])
    end

    it 'runs again once the window has passed' do
      job_class.enqueue_debounced(1, window: 30.seconds)
      travel(31.seconds) { job_class.enqueue_debounced(1, window: 30.seconds) }

      expect(job_class.jobs.size).to eq(2)
    end

    # A Redis store swallows its errors, so a failed write looks like "already pending"; skipping
    # then would mean the job never ran.
    it 'still runs when the cache store is failing' do
      allow(Rails.cache).to receive(:write).and_return(false)
      allow(Rails.cache).to receive(:exist?).and_return(false)

      2.times { job_class.enqueue_debounced(1, window: 30.seconds) }

      expect(job_class.jobs.size).to eq(2)
    end
  end
end
