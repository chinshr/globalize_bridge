module ActionView #:nodoc:
  class PathSet < Array #:nodoc:

    # Find templates for action_view and action_mail templates.
    # If I18n.fallback is defined, will go down the fallback sequence
    #
    # E.g.
    #   
    #   de/index.html yields over index.de.html yields over index.html
    #
    def find_template(original_template_path, format = nil, html_fallback = true)
      
      return original_template_path if original_template_path.respond_to?(:render)
      template_path = original_template_path.sub(/^\//, '')

      formatted_fallbacks = unformatted_fallbacks = I18n.respond_to?(:fallbacks)
      each do |load_path|
        if format && (template = load_path["#{I18n.locale}/#{template_path}.#{format}"])
          return template
        elsif format && (template = load_path["#{template_path}.#{I18n.locale}.#{format}"])
          return template
        elsif format && formatted_fallbacks
          I18n.fallbacks[I18n.locale].reject {|l| l == :root}.each do |fallback_locale|
            if template = load_path["#{fallback_locale}/#{template_path}.#{format}"]
              return template
            elsif template = load_path["#{template_path}.#{fallback_locale}.#{format}"]
              return template
            end
          end
          formatted_fallbacks = false
          retry
        elsif format && (template = load_path["#{template_path}.#{format}"])
          return template
        elsif template = load_path["#{I18n.locale}/#{template_path}"]
          return template
        elsif unformatted_fallbacks
          I18n.fallbacks[I18n.locale].reject {|l| l == :root}.each do |fallback_locale|
            if template = load_path["#{fallback_locale}/#{template_path}"]
              return template
            elsif template = load_path["#{template_path}.#{fallback_locale}"]
              return template
            end
          end
          unformatted_fallbacks = false
          retry
        elsif template = load_path[template_path]
          return template
        # Try to find html version if the format is javascript
        elsif format == :js && html_fallback && template = load_path["#{I18n.locale}/#{template_path}.html"]
          return template
        elsif format == :js && html_fallback && template = load_path["#{template_path}.html"]
          return template
        end
      end

      return Template.new(original_template_path, original_template_path =~ /\A\// ? "" : ".") if File.file?(original_template_path)
      raise MissingTemplate.new(self, original_template_path, format)
    end

  end
end
