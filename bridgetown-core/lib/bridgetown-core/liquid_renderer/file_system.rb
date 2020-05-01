# frozen_string_literal: true

module Bridgetown
  class LiquidRenderer
    class FileSystem < Liquid::LocalFileSystem
      def read_template_file(template_path)
        @site = Bridgetown.sites.first
        cache_key = "component:#{template_path}"
        return @site.liquid_renderer.cache[cache_key] if @site.liquid_renderer.cache[cache_key]

        found_paths = find_template_locations(template_path)
        raise Liquid::FileSystemError, "No such template '#{template_path}'" if found_paths.empty?

        # Last path in the list wins
        filename = found_paths.last
        parse_liquid_component(cache_key, filename)
      end

      def find_template_locations(template_path)
        load_paths = root
        found_paths = []

        load_paths.each do |load_path|
          # Use Liquid's gut checks to verify template pathname
          self.root = load_path
          full_template_path = full_path(template_path)

          # Look for .liquid as well as .html extensions
          path_variants = [
            Pathname.new(full_template_path),
            Pathname.new(full_template_path).sub_ext(".html"),
          ]

          found_paths << path_variants.find(&:exist?)
        end

        # Restore pristine state
        self.root = load_paths

        found_paths.compact
      end

      def parse_liquid_component(cache_key, filename)
        template = ""

        # Strip YAML header
        if Utils.has_yaml_header?(filename)
          begin
            markup = ::File.read(filename)
            template = $POSTMATCH if markup =~ Document::YAML_FRONT_MATTER_REGEXP
          rescue StandardError => e
            Bridgetown.logger.warn "Error reading file #{filename}: #{e.message}"
            raise e if @site.config["strict_front_matter"]
          end
        else
          template = ::File.read(filename)
        end

        # Cache for later use
        Bridgetown.sites.first.liquid_renderer.cache[cache_key] = template

        template
      end
    end
  end
end
