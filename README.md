# Bionomia
Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and then allow them to be claimed by authenticated users via [ORCID](https://orcid.org). Authenticated users may also help other users that have either ORCID or Wikidata identifiers. The web application lives at [https://bionomia.net](https://bionomia.net).

[![Build Status](https://github.com/bionomia/bionomia/actions/workflows/ruby.yml/badge.svg)](https://github.com/bionomia/bionomia/actions)

## Translations

Strings of text in the user interface are translatable via [config/locales](config/locales). Large pages of text are fully translatable in the [views/static_i18n/](views/static_i18n/) directory.

[![Crowdin](https://badges.crowdin.net/bionomia/localized.svg)](https://crowdin.com/project/bionomia)

## Requirements

1. ruby 3.2.1+
2. Elasticsearch 8.10.2+
3. MySQL 8.0.34+
4. Redis 7.0.12+
5. Apache Spark 3+
6. Unix-based operating system to use GNU parallel to process GBIF downloads

## Installation

     $ git clone https://github.com/bionomia/bionomia.git
     $ cd bionomia
     $ gem install bundler
     $ bundle install
     $ mysql -u root bionomia < db/bionomia.sql
     $ cp config/settings/development.yml.sample config/settings/development.yml
     # Adjust content of development.yml
     # Copy and edit production.yml and test.yml as above
     $ RUBY_YJIT_ENABLE=true rackup -p 4567 config.ru

## License

The MIT License (MIT)

Copyright (c) David P. Shorthouse

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
