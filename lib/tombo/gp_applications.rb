# encoding: utf-8
# frozen_string_literal: true

require 'json'
require_relative 'cli_base'

module Tombo
  class GpApplications < CLIBase
    desc 'index', 'gp_applications index'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def index
      json = request('GET', '/gp_applications.json')

      d = json['data']

      raise 'Cannot get gp_applications index' if d.nil? || !d.is_a?(Array)

      output(json)
    end

    desc 'create', 'gp_applications create'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    method_option :gp_contents_code, desc: 'Gameplus contents code provided by Yahoo!', required: true
    method_option :gp_screen_name, desc: 'Gameplus screen name for URL ex.) https://app.tombo.io/_gameplus/[gp_screen_name]', required: true
    def create
      body = {
        'gp_application[gp_contents_code]' => options[:gp_contents_code],
        'gp_application[gp_screen_name]' => options[:gp_screen_name]
      }

      json = request('POST', '/gp_applications.json', nil, body)

      d = json['data']

      if d.nil? || d['type'] != 'gp_applications' || d['id'].nil?
        raise 'Cannot create gp_application'
      end

      output(json)
    end

    desc 'update', 'gp_applications update'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    method_option :gp_application_id, desc: 'The ID of the gp_application to be updated', required: true
    method_option :active_version_id, desc: 'Active Version ID to be updated'
    def update
      body = {}

      if options[:active_version_id]
        body['gp_application[active_version_id]'] = options[:active_version_id]
      end

      raise 'No column are specified to be updated' if body.empty?

      gp_application_id = options[:gp_application_id]

      json = request('PATCH', "/gp_applications/#{gp_application_id}.json", nil, body)

      d = json['data']

      if d.nil? || d['type'] != 'gp_applications' || d['id'].nil?
        raise 'Cannot update gp_application'
      end

      output(json)
    end
  end
end
