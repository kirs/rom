module DataMapper

  class Finalizer
    attr_reader :mapper_registry
    attr_reader :connector_builder
    attr_reader :mapper_builder
    attr_reader :mappers

    def self.run
      new(Mapper.descendants.select { |mapper| mapper.model }).run
    end

    def initialize(mappers)
      @mappers           = mappers
      @mapper_registry   = Mapper.mapper_registry
      @connector_builder = RelationRegistry::Connector::Builder
      @mapper_builder    = Mapper::Builder

      @base_relation_mappers = @mappers.select { |mapper| mapper.respond_to?(:relation_name) }
    end

    def run
      finalize_base_relation_mappers
      finalize_attribute_mappers
      finalize_relationship_mappers

      self
    end

    private

    def finalize_base_relation_mappers
      @base_relation_mappers.each do |mapper|
        next if mapper_registry[mapper.model]

        name     = mapper.relation.name
        relation = mapper.gateway_relation
        aliases  = mapper.aliases

        mapper.relations.new_node(name, relation, aliases)

        mapper.finalize
      end

      @base_relation_mappers.each do |mapper|
        mapper.relationships.each do |relationship|
          connector_builder.call(mapper_registry, mapper.relations, relationship)
        end
      end
    end

    def finalize_attribute_mappers
      mappers.each { |mapper| mapper.finalize_attributes }
    end

    def finalize_relationship_mappers
      @base_relation_mappers.map(&:relations).uniq.each do |relations|
        relations.connectors.each_value do |connector|
          model        = connector.source_model
          relationship = connector.relationship.name
          mapper_class = mapper_registry[model].class
          mapper       = mapper_builder.call(connector, mapper_class)

          if mapper_registry[model, relationship]
            next
          else
            mapper_registry.register(mapper, relationship)
          end
        end
      end

      @base_relation_mappers.each do |mapper|
        mapper.relations.freeze unless mapper.relations.frozen?
      end
    end
  end # class Finalizer
end # module DataMapper
