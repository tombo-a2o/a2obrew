# frozen_string_literal: true

require 'json'
require_relative 'cli_base'

module Tombo
  class ApplicationLocalizes < CLIBase
    desc 'create', 'create an application localize'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    method_option :application_id, desc: 'Target application ID', required: true
    method_option :language_id, desc: 'Language ID', required: true
    method_option :name, desc: 'Localized application name', required: true
    def create
      body = {
        'application_localize[application_id]' => options[:application_id],
        'application_localize[language_id]' => options[:language_id],
        'application_localize[name]' => options[:name]
      }

      json = request('POST', '/application_localizes.json', nil, body)

      d = json['data']

      if d.nil? || d['type'] != 'application_localizes' || d['id'].nil?
        raise 'Cannot update application'
      end

      output(json)
    end
  end
end
