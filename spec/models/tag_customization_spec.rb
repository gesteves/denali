require 'rails_helper'

RSpec.describe TagCustomization, type: :model do
  let(:blog) { create(:blog) }

  describe 'associations' do
    it { should belong_to(:blog).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:tag_list) }

    it 'requires at least one field to be filled' do
      tag_customization = build(:tag_customization,
        blog: blog,
        tag_list: 'test',
        mastodon_hashtags: nil,
        bluesky_hashtags: nil,
        instagram_hashtags: nil,
        threads_topics: nil,
        flickr_groups: nil,
        flickr_albums: nil
      )
      expect(tag_customization).not_to be_valid
      expect(tag_customization.errors[:base]).to include('You need to fill out at least one of the fields')
    end
  end

  describe 'factory' do
    it 'creates a valid tag customization' do
      tag_customization = create(:tag_customization, blog: blog)
      expect(tag_customization).to be_valid
    end
  end

  describe 'hashtag parsing methods' do
    let(:tag_customization) { create(:tag_customization, blog: blog) }

    describe '#mastodon_hashtags_to_a' do
      it 'returns empty array when blank' do
        tag_customization.mastodon_hashtags = nil
        expect(tag_customization.mastodon_hashtags_to_a).to eq([])
      end

      it 'splits hashtags by whitespace' do
        tag_customization.mastodon_hashtags = "#Photography\n#Landscape"
        tag_customization.save!
        expect(tag_customization.mastodon_hashtags_to_a).to contain_exactly('#Landscape', '#Photography')
      end
    end

    describe '#bluesky_hashtags_to_a' do
      it 'returns empty array when blank' do
        tag_customization.bluesky_hashtags = nil
        expect(tag_customization.bluesky_hashtags_to_a).to eq([])
      end

      it 'splits hashtags by whitespace' do
        tag_customization.update!(bluesky_hashtags: "#Photography #Landscape")
        expect(tag_customization.bluesky_hashtags_to_a).to contain_exactly('#Landscape', '#Photography')
      end
    end

    describe '#instagram_hashtags_to_a' do
      it 'returns empty array when blank' do
        tag_customization.instagram_hashtags = nil
        expect(tag_customization.instagram_hashtags_to_a).to eq([])
      end
    end

    describe '#flickr_groups_to_a' do
      it 'returns empty array when blank' do
        tag_customization.flickr_groups = nil
        expect(tag_customization.flickr_groups_to_a).to eq([])
      end
    end

    describe '#flickr_albums_to_a' do
      it 'returns empty array when blank' do
        tag_customization.flickr_albums = nil
        expect(tag_customization.flickr_albums_to_a).to eq([])
      end
    end

    describe '#threads_topics_to_a' do
      it 'returns empty array when blank' do
        tag_customization.threads_topics = nil
        expect(tag_customization.threads_topics_to_a).to eq([])
      end

      it 'splits topics by newline' do
        tag_customization.update!(threads_topics: "Landscape Photography\nNature")
        expect(tag_customization.threads_topics_to_a).to contain_exactly('Landscape Photography', 'Nature')
      end
    end
  end

  describe 'hashtag cleanup' do
    it 'keeps letters from any script' do
      tc = create(:tag_customization, blog: blog, mastodon_hashtags: 'Montaña #東京 Café!')
      expect(tc.mastodon_hashtags_to_a).to contain_exactly('#Montaña', '#東京', '#Café')
    end

    it 'drops entries that are only punctuation' do
      tc = create(:tag_customization, blog: blog, mastodon_hashtags: '#Nature !!! #')
      expect(tc.mastodon_hashtags_to_a).to eq(['#Nature'])
    end
  end

  describe 'merging into an existing customization for the same tags' do
    let!(:existing) { create(:tag_customization, blog: blog, tag_list: 'landscape', mastodon_hashtags: '#Zebra #Nature') }

    it 'replaces it with one whose hashtags are sorted and deduplicated' do
      merged = create(:tag_customization, blog: blog, tag_list: 'landscape', mastodon_hashtags: '#Nature #Apple')

      expect(TagCustomization.exists?(existing.id)).to be false
      expect(merged.reload.mastodon_hashtags_to_a).to eq(['#Apple', '#Nature', '#Zebra'])
    end

    it "leaves other blogs' customizations alone" do
      other = create(:tag_customization, blog: create(:blog), tag_list: 'landscape', mastodon_hashtags: '#Other')

      expect(TagCustomization.exists?(existing.id)).to be true
      expect(other.reload.mastodon_hashtags_to_a).to eq(['#Other'])
    end
  end

  describe 'flickr group cleanup' do
    it 'enqueues the cleanup job after the record is committed' do
      tc = nil
      TagCustomization.transaction do
        tc = create(:tag_customization, blog: blog, flickr_groups: 'https://www.flickr.com/groups/landscapes/')
        expect(UpdateTagCustomizationJob.jobs).to be_empty
      end
      expect(UpdateTagCustomizationJob.jobs.map { |j| j['args'] }).to eq([[tc.id]])
    end
  end

  describe '#matches_tags?' do
    let(:tag_customization) { create(:tag_customization, blog: blog) }

    before do
      tag_customization.tag_list = 'landscape, nature'
      tag_customization.save!
    end

    it 'returns true when all tags match' do
      tags = ActsAsTaggableOn::Tag.where(name: ['landscape', 'nature', 'other'])
      expect(tag_customization.matches_tags?(tags)).to be true
    end

    it 'returns false when not all tags match' do
      tags = ActsAsTaggableOn::Tag.where(name: ['landscape', 'other'])
      expect(tag_customization.matches_tags?(tags)).to be false
    end
  end
end
