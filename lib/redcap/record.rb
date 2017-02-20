require 'hashie'

module Redcap
  class Record < Hashie::Mash
    @@client = nil

    def self.find id
      response = client.records records: [id]
      self.new response.first
    end

    def self.all
      response = client.records
      response.map { |r| self.new r }
    end

    def self.select *fields
      response = client.records fields: fields
      response.map { |r| self.new r }
    end

    def self.where condition
      raise "where only accepts a Hash" unless condition.is_a? Hash
      raise "where only accepts a Hash with one key/value pair" unless condition.size == 1
      key, value = condition.first
      response = client.records filter: "[#{key}] = '#{value}'"
      response.map { |r| self.new r }
    end

    def id
      record_id
    end

    def save
      if record_id
        data = Hash[keys.zip(values)]
        client.update [data]
      else
        max_id = client.records(fields: %w(record_id)).map(&:values).flatten.map(&:to_i).max
        self.record_id = max_id+1
        data = Hash[keys.zip(values)]
        result = client.create [data]
        result.first == record_id.to_s
      end
    end

    def client
      self.class.client
    end

    private

    def self.client
      @@client = Redcap.new unless @@client
      @@client
    end

  end
end
