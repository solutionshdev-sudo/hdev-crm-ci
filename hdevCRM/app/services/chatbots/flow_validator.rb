# Static validation of the flow jsonb (Vue Flow shape). Runs on every save.
class Chatbots::FlowValidator
  NODE_TYPES = %w[start message question condition collect delay handoff tag webhook ai deal end].freeze
  # Nós que pausam a execução — quebram ciclos infinitos.
  WAIT_TYPES = %w[question collect delay end handoff].freeze

  def initialize(flow)
    @flow = flow.presence || {}
    @nodes = Array(@flow['nodes'])
    @edges = Array(@flow['edges'])
  end

  def errors
    list = []
    list << 'must contain exactly one start node' if @nodes.count { |node| node['type'] == 'start' } != 1
    list << 'node ids must be unique' if @nodes.map { |node| node['id'] }.uniq.length != @nodes.length

    unknown = @nodes.map { |node| node['type'] }.uniq - NODE_TYPES
    list << "unknown node types: #{unknown.join(', ')}" if unknown.any?

    node_ids = @nodes.map { |node| node['id'] }
    @edges.each do |edge|
      unless node_ids.include?(edge['source']) && node_ids.include?(edge['target'])
        list << "edge #{edge['id']} points to a missing node"
      end
    end

    list << 'flow contains a loop without a waiting node' if cycle_without_wait?
    list.uniq
  end

  private

  # DFS só pelas arestas de nós que não esperam input: um ciclo nesse subgrafo
  # rodaria infinito dentro de uma única invocação.
  def cycle_without_wait?
    hot_nodes = @nodes.reject { |node| WAIT_TYPES.include?(node['type']) }.map { |node| node['id'] }
    adjacency = @edges.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |edge, hash|
      hash[edge['source']] << edge['target'] if hot_nodes.include?(edge['source']) && hot_nodes.include?(edge['target'])
    end
    visited = {}
    hot_nodes.any? { |node_id| cyclic?(node_id, adjacency, visited, {}) }
  end

  def cyclic?(node_id, adjacency, visited, stack)
    return false if visited[node_id]
    return true if stack[node_id]

    stack[node_id] = true
    result = adjacency[node_id].any? { |neighbour| cyclic?(neighbour, adjacency, visited, stack) }
    stack.delete(node_id)
    visited[node_id] = true
    result
  end
end
