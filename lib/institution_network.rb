# encoding: utf-8

# Example using sfdp
# sfdp -Goutputorder=edgesfirst -Goverlap=prism -Tsvg public/images/graphs/institutions.dot > public/images/graphs/institutions.svg

module Bionomia
  class InstitutionNetwork

    RGL::DOT::GRAPH_OPTS << 'splines'
    RGL::DOT::EDGE_OPTS << 'penwidth'
    RGL::DOT::EDGE_OPTS << 'tailclip'
    RGL::DOT::EDGE_OPTS << 'shared'
    RGL::DOT::NODE_OPTS << 'type'

    def initialize(type = "dot")
      @graph = WeightedGraph.new
      @graph.add_graph_attributes(graph_options)
      @institutions = []
      @type = type
    end

    def graph_options
      {
        bgcolor: "#ffffff",
        splines: "curved"
      }
    end

    def edge_options(penwidth = 1)
      {
        color: "#333333",
        penwidth: penwidth,
        tailclip: "false",
        fontsize: 0,
        shared: pendwidth
      }
    end

    def vertex_options
      {
        color: "#d1d1d1",
        penwidth: 8,
        style: "filled",
        fillcolor: "#e0e0e0",
        fontcolor: "#0000000",
        fontname: "Arial",
        fontsize: 26,
        shape: "box"
      }
    end

    def build
      collect_institutions
      add_edges
      add_attributes
    end

    def write
      if @graph.size > 2
        if @type == "dot"
          write_dot_file
        else
          write_d3_file
        end
      end
    end

    def collect_institutions
      #Hipposideridae, Rhinolophidae
      TaxonOccurrence.joins("JOIN user_occurrences ON taxon_occurrences.occurrence_id = user_occurrences.occurrence_id")
                     .joins(:occurrence)
                     .where(taxon_id: [29470, 52223])
                     .where("user_occurrences.visible = true")
                     .where.not(occurrence: { institutionCode: nil })
                     .pluck(:institutionCode).uniq.each do |code|
          user_ids = Occurrence.joins(:taxon_occurrence)
                               .joins(:user_occurrences)
                               .where(institutionCode: code)
                               .where(taxon_occurrence: { taxon_id: [29470, 52223] })
                               .where(user_occurrences: { action: ["recorded", "recorded,identified", "identified,recorded"] })
                               .pluck(:user_id).uniq
          @institutions << { institution: code, collectors: user_ids }
      end
    end

    def add_edges
      @institutions.combination(2).each do |pair|
        add_edge(pair.first, pair.second)
      end
    end

    def add_attributes
      @institutions.each do |i|
        @graph.add_vertex(i[:institution])
        opts = { label: i[:institution], type: i[:type] }
        @graph.add_vertex_attributes(i[:institution], vertex_options.merge(opts))
      end
    end

    def add_edge(institution1, institution2)
      if institution1[:institution] != institution2[:institution]
        common = institution1[:collectors] & institution2[:collectors]
        @graph.add_edge(institution1[:institution], institution2[:institution], common.size) if common.size > 0
        @graph.add_edge_attributes(institution1[:institution], institution2[:institution], edge_options(common.size)) if common.size > 0
      end
    end

    def write_dot_file
      @graph.write_to_dot_file("public/images/graphs/institutions")
    end

    def write_d3_file
      @graph.write_to_d3_file("public/images/graphs/institutions")
    end

    def to_vis
      @graph.to_vis_graph
    end

  end
end
