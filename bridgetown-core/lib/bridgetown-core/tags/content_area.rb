# frozen_string_literal: true

module Bridgetown
  module Tags
    class ContentAreaTag < Liquid::Block
      def render(context)
        area_name = @markup.strip
        context["content_area_#{area_name}"] = super
        ""
      end
    end
  end
end

Liquid::Template.register_tag("contentarea", Bridgetown::Tags::ContentAreaTag)
