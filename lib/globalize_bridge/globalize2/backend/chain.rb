# Extends message chain to work with I18n::Backend::Database
module GlobalizeBridge # :nodoc:
  module Globalize  
    module Backend
      module Chain
      
        # add this to Globalize::Backend::Chain in order to make it work with Rails 2.3.4
        def reload!
          # get's called on initialization
          # let's not do anything yet
        end
      
        def available_locales
          Locale.available_locales
        end
        
      end
    end
  end
end
Globalize::Backend::Chain.send(:include, GlobalizeBridge::Globalize::Backend::Chain)