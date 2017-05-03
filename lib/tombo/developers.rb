# encoding: utf-8
# frozen_string_literal: true

require 'json'
require_relative 'dotfile'
require_relative 'cli_base'

module Tombo
  class Developers < CLIBase
    desc 'show', 'show developers'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def show
      json = request('GET', '/developer.json')

      d = json['data']

      puts d

      raise 'Cannot get developer' if d.nil? || !d.is_a?(Hash)

      output(json)
    end
  end
end
