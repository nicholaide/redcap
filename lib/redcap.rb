require 'hashie'
require 'json'
require 'rest-client'
require 'logger'
require 'dotenv'
require 'redcap/version'
require 'redcap/configuration'
require 'redcap/record'

Dotenv.load

module Redcap
  attr_reader :configuration

  class << self
    def new(options = {})
      if options.empty? && ENV
        options[:host] = ENV['REDCAP_HOST']
        options[:token] = ENV['REDCAP_TOKEN']
      end
      self.configure = options
      Redcap::Client.new
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure=(options)
      if options.nil?
        @configuration = nil
      else
        @configuration = Configuration.new(options)
      end
    end

    def configure
      yield configuration
      configuration
    end
  end

  class Client
    attr_reader :logger
    attr_writer :log

    def initialize
      @logger = Logger.new STDOUT
    end

    def configuration
      Redcap.configuration
    end

    def log?
      @log ||= false
    end

    def log message
      return unless @log
      @logger.debug message
    end

    def project
      payload = build_payload content: :project
      post configuration.host, payload
    end

    def records records: [], fields: [], filter: nil
      fields |= [:record_id ]if fields.any? # add :record_id to fields unless already there
      payload = build_payload content: :record, records: records, fields: fields, filter: filter
      post configuration.host, payload
    end

    def update data=[]
      payload = {
        token: configuration.token,
        format: configuration.format,
        content: :record,
        overwriteBehavior: :normal,
        type: :flat,
        returnContent: :count,
        data: data.to_json
      }
      result = post configuration.host, payload
      result['count'] == 1
    end

    def create data=[]
      payload = {
        token: configuration.token,
        format: configuration.format,
        content: :record,
        overwriteBehavior: :normal,
        type: :flat,
        returnContent: :ids,
        data: data.to_json
      }
      post configuration.host, payload
    end

    private

    def build_payload content: nil, records: [], fields: [], filter: nil
      payload = {
        token: configuration.token,
        format: configuration.format,
        content: content
      }
      records.each_with_index do |record, index|
        payload["records[#{index}]"] = record
      end if records
      fields.each_with_index do |field, index|
        payload["fields[#{index}]"] = field
      end if fields
      payload[:filterLogic] = filter if filter
      payload
    end

    def post(url, payload = {})
      log "Redcap POST to #{url} with #{payload}"
      response = RestClient.post url, payload
      response = JSON.parse(response)
      log 'Response:'
      log response
      response
    end
  end

end
