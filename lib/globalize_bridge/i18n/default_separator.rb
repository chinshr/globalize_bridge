# Add default separator to I18n only if not present, yet. 
module I18n
  
  @@default_separator = '.'
  
  class << self

    # Returns the current default scope separator. Defaults to '.'
    def default_separator
      @@default_separator
    end

    # Sets the current default scope separator.
    def default_separator=(separator)
      @@default_separator = separator
    end
    
  end
end