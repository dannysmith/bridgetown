# frozen_string_literal: true

module MySite
  class LiquidPageGenerator < Bridgetown::Generator
    def generate(site)
      @site = site
      @components = {}
      @entry_filter = Bridgetown::EntryFilter.new(site)
      load_liquid_components(@site.in_source_dir("_components"))
      @site.data["components"] = @components
      @components.each do |component_filename, component|
        site.pages << ComponentPage.new(site, component_filename, component)
      end
    end

    def load_liquid_components(dir)
      return unless File.directory?(dir) && !@entry_filter.symlink?(dir)

      entries = Dir.chdir(dir) do
        Dir["*.{liquid,html}"] + Dir["*"].select { |fn| File.directory?(fn) }
      end

      entries.each do |entry|
        path = @site.in_source_dir(dir, entry)
        next if @entry_filter.symlink?(path)

        if File.directory?(path)
          load_liquid_components(path)
        else
          yaml_data = nil
          if Bridgetown::Utils.has_yaml_header?(path)
            begin
              content = ::File.read(path)
              file_content = $POSTMATCH if content =~ Bridgetown::Document::YAML_FRONT_MATTER_REGEXP
              yaml_data = SafeYAML.load(Regexp.last_match(1))
            rescue Psych::SyntaxError => e
              Bridgetown.logger.warn "YAML Exception reading #{path}: #{e.message}"
              raise e if @site.config["strict_front_matter"]
            rescue StandardError => e
              Bridgetown.logger.warn "Error reading file #{path}: #{e.message}"
              raise e if @site.config["strict_front_matter"]
            end
          end

          if yaml_data
            key = sanitize_filename(File.basename(path, ".*"))
            key = File.join(File.dirname(path.sub(@site.in_source_dir("_components") + "/", "")), key)
            @components[key] = yaml_data.merge({
              "relative_path" => key,
            })
          end
        end
      end
    end

    def sanitize_filename(name)
      name.gsub(%r![^\w\s-]+|(?<=^|\b\s)\s+(?=$|\s?\b)!, "")
        .gsub(%r!\s+!, "_")
    end
  end

  # A Page subclass used in the `CategoryPageGenerator`
  class ComponentPage < Bridgetown::Page
    def initialize(site, component_name, component)
      @site = site
      @base = site.source # start in src
      @dir  = "components/#{component_name}" # aka src/categories/<category>
      @name = "index.html" # filename
      process(@name) # saves internal filename and extension information

      # Load in front matter and content from the layout
      read_yaml("_layouts", "component_preview.html")

      # Inject data into the generated page:
      data["component"] = component
      data["title"] = component["name"]
    end
  end
end

module MySite
  class ComponentPreviewTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      page = context.registers[:page]
      component = page["component"]
      relative_path = component["relative_path"]
      preview_path = site.in_source_dir("_components", relative_path + ".preview.html")

      input = File.read(preview_path)

      liquid_options = site.config["liquid"]
      info = {
        registers: { site: site, page: page },
        strict_filters: liquid_options["strict_filters"],
        strict_variables: liquid_options["strict_variables"],
      }

      template = site.liquid_renderer.file(preview_path).parse(input)
      template.warnings.each do |e|
        Bridgetown.logger.warn "Liquid Warning:",
                               LiquidRenderer.format_error(e, preview_path)
      end
      template.render!(site.site_payload.merge({ page: page }), info)
    end
  end
end

Liquid::Template.register_tag("component_previews", MySite::ComponentPreviewTag)
