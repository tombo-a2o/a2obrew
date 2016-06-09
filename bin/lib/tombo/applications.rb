# encoding: utf-8

require 'json'
require_relative 'dotfile'
require_relative 'cli_base'

module Tombo
  class Applications < CLIBase
    desc 'list', 'application list'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def list
      json = request('GET', '/applications.json')

      d = json['data']

      raise 'Cannot get application list' if d.nil? || !d.is_a?(Array)

      output(json)
    end
  end
end
