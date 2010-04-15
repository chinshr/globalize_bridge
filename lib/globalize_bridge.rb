require 'globalize_bridge/i18n/default_separator' unless defined?(I18n::default_separator)

require 'globalize_bridge/globalize/ext/core_hooks'
require 'globalize_bridge/globalize/ext/core'
require 'globalize_bridge/globalize/ext/i18n'


require 'globalize_bridge/globalize/action_controller/rescue'
require 'globalize_bridge/globalize/action_view/paths'

require 'globalize_bridge/globalize2/model/translated_internal'
require 'globalize_bridge/globalize2/backend/chain'

require 'globalize_bridge/i18n_backend_database/models/translation'
require 'globalize_bridge/i18n_backend_database/models/model_translation'
require 'globalize_bridge/i18n_backend_database/database' if defined?(I18n::Backend::Database)
require 'globalize_bridge/i18n_backend_database/cache' unless defined?(I18n::cache_store)

