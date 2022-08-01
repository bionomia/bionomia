# encoding: utf-8
class String
  def is_orcid?
    ::Bionomia::Identifier.is_orcid_regex.match?(self) &&
    ::Bionomia::Identifier.orcid_valid_checksum(self)
  end

  def is_wiki_id?
    ::Bionomia::Identifier.is_wiki_regex.match?(self)
  end

  def is_doi?
    ::Bionomia::Identifier.is_doi_regex.match?(self)
  end

  def is_youtube_id?
    ::Bionomia::Identifier.is_youtube_id_regex.match?(self)
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

  def library_congress_from_url
    ::Bionomia::Identifier.extract_library_congress_regex.match(self)[0] rescue nil
  end

end

module Bionomia
  class Identifier

    class << self
      def is_orcid_regex
        /^0000-000(1-[5-9]|2-[0-9]|3-[0-4])\d{3}-\d{3}[\dX]$/
      end

      def is_wiki_regex
        /^Q[0-9]{1,}$/
      end

      def is_doi_regex
        /^10.\d{4,9}\/[-._;()\/:<>A-Z0-9]+$/i
      end

      def is_youtube_id_regex
        /^[A-Z_]{11}$/i
      end

      def orcid_valid_checksum(orcid_string)
        parts = orcid_string.scan(/[0-9X]/)
        mod = parts[0..14].map(&:to_i)
                          .inject { |sum, n| (sum + n)*2 }
                          .modulo(11)
        result = (12 - mod) % 11
        parts.last == ((result == 10) ? "X" : result.to_s)
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

      def extract_library_congress_regex
        /(?<=id.loc.gov\/authorities\/names\/)(.*)/
      end

    end

  end
end
