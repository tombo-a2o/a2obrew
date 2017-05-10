# encoding: utf-8
# frozen_string_literal: true

require 'json'
require_relative 'cli_base'

module Tombo
  class Developers < CLIBase
    desc 'show', 'show developers'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def show
      json = request('GET', '/developer.json')

      d = json['data']

      raise 'Cannot get developer' if d.nil? || !d.is_a?(Hash)

      output(json)
    end

    desc 'create', 'create developers'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    method_option :name, desc: 'Developer name', required: true
    method_option :email, desc: 'Developer email', required: true
    method_option :password, desc: 'Password', required: true
    method_option :password_confirmation, desc: 'Password(confirmation)', required: true
    method_option :country_id, desc: 'Country ID', required: true
    method_option :currency_id, desc: 'Currency ID', required: true
    method_option :language_id, desc: 'Language ID', required: true
    method_option :time_zone_id, desc: 'Time Zone ID', required: true
    def create
      body = {
        'developer[name]' => options[:name],
        'developer[email]' => options[:email],
        'developer[password]' => options[:password],
        'developer[password_confirmation]' => options[:password_confirmation],
        'developer[country_id]' => options[:country_id],
        'developer[currency_id]' => options[:currency_id],
        'developer[language_id]' => options[:language_id],
        'developer[time_zone_id]' => options[:time_zone_id]
      }

      json = request('POST', '/developers.json', nil, body)

      d = json['data']

      raise 'Cannot get developer' if d.nil? || !d.is_a?(Hash)

      output(json)
    end
  end
end
