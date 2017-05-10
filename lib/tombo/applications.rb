# encoding: utf-8
# frozen_string_literal: true

require 'json'
require_relative 'cli_base'

module Tombo
  class Applications < CLIBase
    desc 'index', 'applications index'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def index
      json = request('GET', '/applications.json')

      d = json['data']

      raise 'Cannot get applications index' if d.nil? || !d.is_a?(Array)

      output(json)
    end

    desc 'update', 'applications update'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    method_option :application_id, desc: 'The ID of the application to be updated', required: true
    method_option :active_version_id, desc: 'Active Version ID to be updated'
    def update
      body = {}

      if options[:active_version_id]
        body['application[active_version_id]'] = options[:active_version_id]
      end

      raise 'No column are specified to be updated' if body.empty?

      application_id = options[:application_id]

      json = request('PATCH', "/applications/#{application_id}.json", nil, body)

      d = json['data']

      if d.nil? || d['type'] != 'applications' || d['id'].nil?
        raise 'Cannot update application'
      end

      output(json)
    end
  end
end
