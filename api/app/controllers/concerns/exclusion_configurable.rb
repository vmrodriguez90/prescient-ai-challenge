module ExclusionConfigurable
  extend ActiveSupport::Concern

  EXCLUSION_CONFIG_PATH = Rails.root.join('data', 'exclusion_config.yaml')

  private

  def load_exclusion_config
    return {} unless File.exist?(EXCLUSION_CONFIG_PATH)

    YAML.safe_load(File.read(EXCLUSION_CONFIG_PATH)) || {}
  end
end
