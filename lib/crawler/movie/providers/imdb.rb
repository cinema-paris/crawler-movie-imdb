require 'crawler/movie'
require 'faraday'
require 'nokogiri'
require 'date'
require 'active_support/core_ext/object/blank'
require 'uri'
require 'time'

module Crawler
  module Movie
    module Providers
      module Imdb
        def self.find(id)
          response = Faraday.get("https://www.imdb.com/title/#{id}/")

          return if !response.success? || !response.body

          html = Nokogiri::HTML(response.body)
          widget = html.css('#title-overview-widget')
          title = widget.css('.title_wrapper h1 > text()').text.tr("\u00A0", '').strip
          original_title = widget.css('.title_wrapper .originalTitle > text()').text.presence
          genres = (html.css('#titleStoryLine .see-more:contains("Genres:") a') || []).map { |genre| genre.text.strip }
          poster = widget.css('.poster img')
          poster_url = poster.present? ? "#{poster.attr('src').value.split('@').first}@._V1_.jpg" : nil
          overview = widget.css('.summary_text').text.sub(/See full (synopsis|summary) »/, '').strip
          overview = nil if overview == 'Add a Plot »'
          release_date_matches = html.css('#titleDetails .txt-block:contains("Release Date:") > text()').text.match(/(?<release_date>\d{1,2} \w+ \d{4})/)
          release_date = release_date_matches && Date.parse(release_date_matches[:release_date])
          original_languages = (html.css('#titleDetails .txt-block:contains("Language:") a') || []).map do |lang|
            uri = URI(lang.attr('href'))
            params = URI.decode_www_form(uri.query).to_h
            params['primary_language']
          end

          {
            id: id,
            source: 'internet-movie-database',
            title: title,
            poster_url: poster_url,
            backdrop_url: nil,
            original_languages: original_languages,
            original_titles: original_title,
            genres: genres,
            overview: overview,
            release_date: release_date
          }
        end

        def self.search(query)
          movies = []
          current_start = 1

          loop do
            response = Faraday.get('https://www.imdb.com/search/title',
              title: query,
              title_type: 'feature,short',
              count: 50,
              start: current_start
            )

            break if !response.success? || !response.body

            html = Nokogiri::HTML(response.body)
            results = html.css('.lister .lister-item').map do |movie|
              item_content = movie.css('.lister-item-content')
              title = item_content.css('.lister-item-header a').text
              genres = item_content.css('.genre').text.strip.split(', ')
              overview = item_content.css('.text-muted')[2].text.sub(/See full (synopsis|summary) »/, '').strip
              overview = nil if overview == 'Add a Plot'
              year_matches = item_content.css('.lister-item-year').text.match(/\((?<year>\d+)\)/)
              release_date = year_matches && Date.parse("#{year_matches[:year]}-1-1")
              item_image = movie.css('.lister-item-image img')
              id = item_image.attr('data-tconst').value
              poster_url = item_image.attr('loadlate').value.split('@').first
              poster_url = nil if poster_url.match?(%r{/nopicture/})
              poster_url += '@._V1_.jpg' if poster_url
              details = find(id)

              next details if details

              {
                id: id,
                source: 'internet-movie-database',
                title: title,
                poster_url: poster_url,
                backdrop_url: nil,
                original_language: nil,
                original_title: nil,
                genres: genres,
                overview: overview,
                release_date: release_date
              }
            end

            movies.concat(results)
            next_page = html.css('.lister-page-next').first

            break unless next_page

            current_start += results.length
          end

          movies
        end
      end
    end
  end
end

Crawler::Movie.add_provider :imdb, score: 0.9
