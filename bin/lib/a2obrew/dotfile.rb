require 'inifile'

module A2OBrew
  class Dotfile
    def initialize(profile_name = nil, base_path = nil)
      @base_path = checked_base_path(base_path)

      section = profile_name.nil? ? 'default' : "profile #{profile_name}"
      @config_path = checked_config_path(File.join(@base_path, 'config'))

      @config = IniFile.load(@config_path)[section]
    end

    def developer_portal_uri
      @config['developer_portal_uri']
    end

    private

    def checked_base_path(base_path)
      if base_path.nil?
        base_path = File.join(ENV['HOME'], '.tombo')
        FileUtils.mkdir(base_path) unless File.exist?(base_path)
      end

      raise "Cannot file base_path #{base_path}" unless File.exist?(base_path)
      base_path
    end

    def checked_config_path(config_path)
      unless File.exist?(config_path)
        File.open(config_path, 'w') do |f|
          f.puts <<EOF
[default]
developer_portal_uri = https://developer.tom.bo/
EOF
        end
      end
      config_path
    end
  end
end
