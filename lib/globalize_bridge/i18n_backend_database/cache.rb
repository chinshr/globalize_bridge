# Adding a mechanism to define a global cache store for I18n unless it is already 
# defined by a future version of the I18n gem (http://github.com/svenfuchs/i18n)
#
# Particularly, works around the issue I18n::Backend::Database together with 
# using backend chaining, where the current mechanism of defining a cache, e.g.
#
#   I18n.backend.cache_store = :memory_store
#
# no longer smoothly works. The standard way for defining I18n caching is:
#
#   I18n.backend = Globalize::Backend::Chain.new(Globalize::Backend::Static, I18n::Backend::Database)
#   I18n.cache_store = ActiveSupport::Cache.lookup_store(:memory_store)
#
# and as that it should be forward compatible with future versions of I18n, see:
#
#   http://github.com/svenfuchs/i18n
#
module I18n
  class << self
    @@cache_store = nil
    @@cache_namespace = nil
 
    def cache_store
      @@cache_store
    end
 
    def cache_store=(store)
      @@cache_store = store
    end
 
    def cache_namespace
      @@cache_namespace
    end
 
    def cache_namespace=(namespace)
      @@cache_namespace = namespace
    end
 
    def perform_caching?
      !cache_store.nil?
    end
  end
end