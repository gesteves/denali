require 'elasticsearch/rails/tasks/import'

namespace :elasticsearch do
  namespace :update do
    desc "Updates entry index with new settings, mappings, and synonyms. Use TAG_COUNT=N to customize (default 100)."
    task :entry => :environment do
      tag_count = (ENV['TAG_COUNT'] || 100).to_i

      puts "Fetching top #{tag_count} tags by usage..."
      tags = ActsAsTaggableOn::Tag
        .where('taggings_count > 0')
        .order(taggings_count: :desc)
        .limit(tag_count)
        .pluck(:name)

      puts "Found #{tags.count} tags, generating synonyms with Claude..."

      claude = Claude.new
      body = {
        model: 'claude-haiku-4-5',
        max_tokens: 4096,
        tools: [{
          name: 'generate_synonyms',
          description: 'Generate Elasticsearch synonym mappings for search',
          input_schema: {
            type: 'object',
            properties: {
              synonyms: {
                type: 'array',
                items: { type: 'string' },
                description: 'Array of synonym rules in Elasticsearch format: "term1, term2 => canonical_term"'
              }
            },
            required: ['synonyms']
          }
        }],
        tool_choice: { type: 'tool', name: 'generate_synonyms' },
        messages: [{ role: 'user', content: tags.join(', ') }],
        system: <<~PROMPT
          You are generating Elasticsearch synonym mappings for a photography blog search.
          Given a list of tags, generate synonym rules that map common variations,
          abbreviations, and alternate spellings to their canonical form.

          Rules format: "variation1, variation2 => canonical_term"

          Guidelines:
          - Map abbreviations: "b&w, bw, bnw => black and white"
          - Map city nicknames: "nyc, ny => new york city", "sf => san francisco"
          - Map park abbreviations: "yosemite np => yosemite national park"
          - Map brand variations: "fuji => fujifilm"
          - Map common misspellings if likely
          - Only generate synonyms for tags that have meaningful variations
          - Skip tags that are already canonical (no synonyms needed)
          - Keep canonical terms lowercase for consistency
        PROMPT
      }

      response = claude.create_message(body)
      tool_use = response['content']&.find { |c| c['type'] == 'tool_use' }

      if tool_use && tool_use['input']['synonyms']
        synonyms = tool_use['input']['synonyms']
        puts "Generated #{synonyms.count} synonym rules:"
        synonyms.each { |s| puts "  - #{s}" }

        puts "\nStoring synonyms in cache..."
        Rails.cache.write(Entry::SYNONYMS_CACHE_KEY, synonyms)

        puts "Deleting existing index..."
        Entry.__elasticsearch__.delete_index! rescue nil

        puts "Creating index with new settings..."
        Entry.__elasticsearch__.create_index!

        puts "Importing entries (this may take a few minutes)..."
        Entry.import(force: true, batch_size: 100)

        puts "\nDone! Index has been updated with:"
        puts "  - #{synonyms.count} synonym rules"
        puts "  - Custom search analyzer"
        puts "  - Fuzzy matching support"
        puts "  - tag_names and tag_slugs keyword fields"
      else
        puts "Error: Claude did not return synonyms"
        exit 1
      end
    end
  end
end
