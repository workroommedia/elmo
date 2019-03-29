# frozen_string_literal: true

module Results
  # View methods for rendering hierarchical response form
  class ResponseFormContext
    attr_reader :path, :options, :visible_depth

    def initialize(path: [], visible_depth: 0, **options)
      @path = path
      @options = options
      @visible_depth = visible_depth
    end

    def read_only?
      options[:read_only] == true
    end

    def add(item, visible: true)
      self.class.new(path: path + [item], visible_depth: visible_depth + (visible ? 1 : 0), **options)
    end

    def index
      path.last
    end

    def depth
      path.size
    end

    def full_path
      if path.present?
        ["children"] + path.zip(["children"] * (depth - 1)).flatten.compact
      else
        []
      end
    end

    def input_name(*names)
      "response[root]" + (full_path + names).map { |item| "[#{item}]" }.join
    end

    def input_id(*names)
      "response_root_" + (full_path + names).join("_")
    end

    # Dash separated list of indices leading to this node, e.g. "0-2-1-1-0"
    # Used for uniquely identifying DOM elements.
    def path_str
      path.join("-")
    end

    # Find this context's path in the given response
    # Returns an answer node
    def find(response)
      find_node(response.root_node, path.dup)
    end

    private

    def find_node(node, indices)
      if indices.empty?
        node
      else
        index = indices.shift
        index = 0 if index == "__INDEX__"
        child = node.children[index]

        # It's possible that this context's path refers to a repeat item
        # which may not exist in the given node tree.  If that's the case,
        # we return the first sibling instead.  This happens when finding
        # a repeat template node in the blank response tree.
        child = node.children[0] if child.nil?

        find_node(child, indices)
      end
    end
  end
end
