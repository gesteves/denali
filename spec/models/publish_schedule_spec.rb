require 'rails_helper'

RSpec.describe PublishSchedule, type: :model do
  describe 'associations' do
    it { should belong_to(:blog).optional }
  end

  describe 'validations' do
    subject { create(:publish_schedule) }

    it { should validate_uniqueness_of(:hour) }
  end

  describe 'factory' do
    it 'creates a valid publish schedule' do
      publish_schedule = create(:publish_schedule)
      expect(publish_schedule).to be_valid
    end
  end

  describe 'touching entries' do
    let(:blog) { Blog.first || create(:blog) }
    let(:user) { create(:user) }

    it 'touches queued entries when schedule is saved' do
      entry = create(:entry, :queued, blog: blog, user: user)
      original_updated_at = entry.updated_at

      sleep(0.01)
      create(:publish_schedule, blog: blog)

      entry.reload
      expect(entry.updated_at).not_to eq(original_updated_at)
    end

    it 'touches queued entries when schedule is updated' do
      schedule = create(:publish_schedule, blog: blog)
      entry = create(:entry, :queued, blog: blog, user: user)
      original_updated_at = entry.updated_at

      sleep(0.01)
      schedule.update!(hour: 15)

      entry.reload
      expect(entry.updated_at).not_to eq(original_updated_at)
    end

    it 'touches queued entries when schedule is destroyed' do
      schedule = create(:publish_schedule, blog: blog)
      entry = create(:entry, :queued, blog: blog, user: user)
      original_updated_at = entry.updated_at

      sleep(0.01)
      schedule.destroy

      entry.reload
      expect(entry.updated_at).not_to eq(original_updated_at)
    end

    it 'does not touch published entries' do
      entry = create(:entry, :published, blog: blog, user: user)
      original_updated_at = entry.updated_at

      sleep(0.01)
      create(:publish_schedule, blog: blog)

      entry.reload
      # Use be_within to handle database timestamp precision differences
      expect(entry.updated_at).to be_within(0.001.seconds).of(original_updated_at)
    end
  end
end
