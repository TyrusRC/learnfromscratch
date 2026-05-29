# frozen_string_literal: true
#
# Wikilinks plugin — converts Obsidian-style [[slug]] and [[slug|alias]]
# references inside wiki collection documents into proper Jekyll links.
#
# Resolution order for a slug:
#   1. A wiki document whose front-matter `slug` equals the target.
#   2. A wiki document whose basename (without extension) equals the target.
#   3. A wiki document whose front-matter `aliases` list contains the target.
#
# Unresolved targets are rendered as a span with class `wikilink-broken`
# so they are visible in the rendered page without breaking the build.

module Wikilinks
  PATTERN = /\[\[([^\[\]\|\n]+?)(?:\|([^\[\]\n]+?))?\]\]/.freeze

  class Index
    def initialize(site)
      @by_key = {}
      site.collections.each_value do |collection|
        collection.docs.each do |doc|
          register(doc, doc.data["slug"]) if doc.data["slug"]
          register(doc, File.basename(doc.relative_path, ".*"))
          Array(doc.data["aliases"]).each { |a| register(doc, a) }
        end
      end
    end

    def lookup(target)
      @by_key[normalize(target)]
    end

    private

    def register(doc, key)
      return if key.nil? || key.to_s.empty?

      @by_key[normalize(key)] ||= doc
    end

    def normalize(key)
      key.to_s.strip.downcase
    end
  end

  class Converter
    def initialize(site)
      @site = site
      @index = Index.new(site)
      @baseurl = site.config["baseurl"].to_s
    end

    def render(doc)
      return unless doc.content.is_a?(String)

      doc.content = doc.content.gsub(PATTERN) do |_match|
        target = Regexp.last_match(1)
        alias_text = Regexp.last_match(2)
        replacement_for(target, alias_text)
      end
    end

    private

    def replacement_for(target, alias_text)
      label = (alias_text || target).strip
      hit = @index.lookup(target)
      if hit
        href = "#{@baseurl}#{hit.url}"
        %(<a class="wikilink" href="#{href}">#{label}</a>)
      else
        %(<span class="wikilink wikilink-broken" title="Unresolved: #{target.strip}">#{label}</span>)
      end
    end
  end
end

Jekyll::Hooks.register :site, :pre_render do |site|
  converter = Wikilinks::Converter.new(site)
  site.collections.each_value do |collection|
    collection.docs.each do |doc|
      next unless doc.content.is_a?(String) && doc.content.include?("[[")

      converter.render(doc)
    end
  end
end
