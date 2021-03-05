# encoding: utf-8

module Bionomia

  # FROM https://github.com/wpm/Ruby-Editalign/blob/master/lib/editalign/graph.rb
  class WeightedGraph < RGL::AdjacencyGraph

    def initialize(edgelist_class = Set, *other_graphs)
      super
      @weights = {}
      @graph_attributes = {}
      @vertex_attributes = {}
      @edge_attributes = {}
    end

    # Create a graph from an array of [source, target, weight] triples.
    #
    #  >> g=Collector::Disambiguator::WeightedGraph[:a, :b, 2, :b, :c, 3, :a, :c, 6]
    #  >> puts g
    #  (a-2-b)
    #  (a-6-c)
    #  (b-3-c)
    def self.[] (*a)
      result = new
      0.step(a.size-2, 3) { |i| result.add_edge(a[i], a[i+1], a[i+2]) }
      result
    end

    def to_s
      # TODO Sort toplogically instead of by edge string.
      (edges.sort_by {|e| e.to_s} +
       isolates.sort_by {|n| n.to_s}).map { |e| e.to_s }.join("\n")
    end

    # A set of all the unconnected vertices in the graph.
    def isolates
      edges.inject(Set.new(vertices)) { |iso, e| iso -= [e.source, e.target] }
    end

    def add_graph_attributes(a)
      @graph_attributes.merge! a
    end

    def graph_attributes
      @graph_attributes
    end

    # Add a weighted edge between two verticies.
    #
    # [_u_] source vertex
    # [_v_] target vertex
    # [_w_] weight
    def add_edge(u, v, w)
      super(u,v)
      @weights[[u,v]] = w
    end

    def add_edge_attributes(u, v, a)
      @edge_attributes[[u,v]] = a
    end

    def edge_attributes(u,v)
      @edge_attributes[[u,v]] || @edge_attributes[[v,u]] || {}
    end

    def add_vertex_attributes(v, a)
      @vertex_attributes[v] = a
    end

    def vertex_attributes(v)
      @vertex_attributes[v] || {}
    end

    # Edge weight
    #
    # [_u_] source vertex
    # [_v_] target vertex
    def weight(u, v)
      @weights[[u,v]] || @weights[[v,u]]
    end

    # Remove the edge between two verticies.
    #
    # [_u_] source vertex
    # [_v_] target vertex
    def remove_edge(u, v)
      super
      @weights.delete([u,v])
    end

    # The class used for edges in this graph.
    def edge_class
      WeightedEdge
    end

    # Return the array of WeightedDirectedEdge objects of the graph.
    def edges
      result = []
      c = edge_class
      each_edge { |u,v| result << c.new(u, v, self) }
      result
    end

    # Create a dot file to depict the graph's vertices with decorated edges
    def write_to_dot_file(dotfile="graph")
      src = dotfile + ".dot"

      File.open(src, 'w') do |f|
        f << self.to_dot_graph.to_s << "\n"
      end
      src
    end

    def vertex_label(v)
      v.to_s
    end

    def vertex_id(v)
      v
    end

    def to_dot_graph
      options = {
        name: self.class.name.gsub(/:/, '_'),
        fontsize: 8
      }
      options.merge! graph_attributes

      graph          = RGL::DOT::Graph.new(options.stringify_keys)
      edge_class     = RGL::DOT::Edge

      each_vertex do |v|
        options = {
          name: vertex_id(v),
          fontsize: 8,
          label: vertex_label(v)
        }
        options.merge! vertex_attributes(v)
        graph << RGL::DOT::Node.new(options.stringify_keys)
      end

      each_edge do |u, v|
        options = {
          from: vertex_id(u),
          to: vertex_id(v),
          fontsize: 8,
          label: weight(u,v)
        }
        options.merge! edge_attributes(u, v)
        graph << edge_class.new(options.stringify_keys)
      end

      graph
    end

    def write_to_d3_file(d3file="d3")
      src = d3file + ".json"

      File.open(src, 'w') do |f|
        f << self.to_d3_graph.to_json
      end
      src
    end

    def to_d3_graph
      nodes = []
      each_vertex do |v|
        options = { name: v.to_s }
        options.merge! vertex_attributes(v)
        nodes << options
      end
      links = edges.map{ |e| { source: vertices.index(e.source), target: vertices.index(e.target), value: e.weight } }
      { nodes: nodes, edges: links }
    end

    def to_vis_graph
      nodes = []
      each_vertex do |v|
        options = { label: v.to_s }
        options.merge! vertex_attributes(v)
        nodes << options
      end
      links = edges.map{ |e| { from: vertex_attributes(e.source)[:id], to: vertex_attributes(e.target)[:id], value: e.weight, title: e.weight } }
      { nodes: nodes, edges: links }
    end

    # Create a dot file and png to depict the graph's vertices with decorated edges
    def write_to_graphic_file(fmt='png', dotfile="graph")
      src = dotfile + ".dot"
      dot = dotfile + "." + fmt

      File.open(src, 'w') do |f|
        f << self.to_dot_graph.to_s << "\n"
      end

      system("dot -T#{fmt} #{src} -o #{dot}")
      dot
    end

  end

  # An undirected edge that can display its weight as part of stringification.
  class WeightedEdge < RGL::Edge::UnDirectedEdge

    # [_u_] source vertex
    # [_v_] target vertex
    # [_g_] the graph in which this edge appears
    def initialize(a, b, g)
      super(a,b)
      @graph = g
    end

    # The weight of this edge.
    def weight
      @graph.weight(source, target)
    end

     def to_s
       "(#{source}-#{weight}-#{target})"
     end
  end

end
