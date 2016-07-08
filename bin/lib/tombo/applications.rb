# encoding: utf-8

require 'json'
require_relative 'dotfile'
require_relative 'cli_base'

module Tombo
  class Applications < CLIBase
    desc 'index', 'application list index'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def index
      json = request('GET', '/applications.json')

      d = json['data']

      raise 'Cannot get application index' if d.nil? || !d.is_a?(Array)

      output(json)
    end
  end
end
