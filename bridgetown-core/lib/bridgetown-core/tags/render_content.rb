# frozen_string_literal: true

module Bridgetown
  module Tags
    class BlockRenderTag < Liquid::Block
      def render(context)
        context.stack({}) do
          content = super.gsub(%r!^[ \t]+!, "") # unindent the incoming text
          areas = gather_content_areas(context)

          site = context.registers[:site]
          converter = site.find_converter_instance(Bridgetown::Converters::Markdown)
          markdownified_content = converter.convert(content)
          context["componentcontent"] = markdownified_content

          render_params = [@markup, "content: componentcontent"]
          unless areas.empty?
            areas.each do |area_name, area_content|
              area_name = area_name.sub("content_area_", "")
              context[area_name] = converter.convert(area_content.gsub(%r!^[ \t]+!, ""))
              render_params.push "#{area_name}: #{area_name}"
            end
          end

          Liquid::Render.parse("render", render_params.join(","), nil, @parse_context)
            .render_tag(context, +"")
        end
      end

      private

      def gather_content_areas(context)
        return {} unless context.scopes[0].keys.find { |k| k.to_s.start_with? "content_area_" }

        context.scopes[0].select { |k| k.to_s.start_with? "content_area_" }
      end
    end
  end
end

Liquid::Template.register_tag("rendercontent", Bridgetown::Tags::BlockRenderTag)
