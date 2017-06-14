# encoding: utf-8
# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

script_path = File.dirname(__FILE__)
a2obrew_path = File.expand_path("#{script_path}/../")

$LOAD_PATH << "#{a2obrew_path}/lib"
require 'bundler'
Bundler.setup(:default)

require 'a2obrew/cli'

config = "#{a2obrew_path}/a2oconfig.rb"
require config

A2OBrew::CLI.start(ARGV)
