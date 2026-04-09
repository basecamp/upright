module Upright
  class ProbeTypeRegistry
    ProbeType = Data.define(:type, :name, :icon)

    include Enumerable

    def initialize
      @probe_types = []
    end

    def register(type, name:, icon:)
      type = type.to_s
      @probe_types.reject! { |pt| pt.type == type }
      @probe_types << ProbeType.new(type:, name:, icon:)
    end

    def types
      @probe_types.map(&:type)
    end

    def find(type)
      @probe_types.find { |pt| pt.type == type.to_s }
    end

    def unregister(type)
      @probe_types.reject! { |pt| pt.type == type.to_s }
    end

    def each(&block)
      @probe_types.each(&block)
    end
  end
end
