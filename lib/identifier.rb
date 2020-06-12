# encoding: utf-8
class String
  def is_orcid?
    ::Bionomia::Identifier.is_orcid_regex.match?(self)
  end
  def is_wiki_id?
    ::Bionomia::Identifier.is_wiki_regex.match?(self)
  end
  def is_doi?
    ::Bionomia::Identifier.is_doi_regex.match?(self)
  end

  def orcid_from_url
    ::Bionomia::Identifier.extract_orcid_regex.match(self)[0] rescue nil
  end
  def wiki_from_url
    ::Bionomia::Identifier.extract_wiki_regex.match(self)[0] rescue nil
  end
  def ipni_from_url
    ::Bionomia::Identifier.extract_ipni_regex.match(self)[0] rescue nil
  end
  def viaf_from_url
    ::Bionomia::Identifier.extract_viaf_regex.match(self)[0] rescue nil
  end
  def bhl_from_url
    ::Bionomia::Identifier.extract_bhl_regex.match(self)[0] rescue nil
  end
  def isni_from_url
    URI.decode_www_form_component(::Bionomia::Identifier.extract_isni_regex.match(self)[0]) rescue nil
  end
  def zoobank_from_url
    ::Bionomia::Identifier.extract_zoobank_regex.match(self)[0] rescue nil
  end
end

module Bionomia
  class Identifier

    class << self
      def is_orcid_regex
        /^(\d{4}-){3}\d{3}[0-9X]{1}$/
      end

      def is_wiki_regex
        /^Q[0-9]{1,}$/
      end

      def is_doi_regex
        /^10.\d{4,9}\/[-._;()\/:<>A-Z0-9]+$/i
      end

      def extract_orcid_regex
        /(?<=orcid\.org\/)(\d{4}-){3}\d{3}[0-9X]{1}/
      end

      def extract_wiki_regex
        /(?:wikidata\.org\/(entity|wiki)\/)\K(Q[0-9]{1,})/
      end

      def extract_ipni_regex
        /(?:ipni.org\/(?:.*)\?id\=)\K(.*)/
      end

      def extract_viaf_regex
        /(?<=viaf.org\/viaf\/)([0-9]{1,})/
      end

      def extract_bhl_regex
        /(?<=biodiversitylibrary.org\/creator\/)([0-9]{1,})/
      end

      def extract_isni_regex
        /(?<=isni.org\/)(.*)/
      end

      def extract_zoobank_regex
        /(?<=zoobank.org\/Authors\/)(.*)/
      end

    end

  end
end
