require 'crawler/movie'
require 'faraday'
require 'nokogiri'
require 'date'

module Crawler
  module Movie
    module Providers
      module Imdb
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
              item_image = movie.css('.lister-item-image img')
              id = item_image.attr('data-tconst').value
              poster_url = item_image.attr('loadlate').value.split('@').first
              poster_url = nil if poster_url.match?(%r{/nopicture/})
              poster_url += '@._V1_.jpg' if poster_url

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
                release_date: year_matches && Date.parse("#{year_matches[:year]}-1-1")
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
