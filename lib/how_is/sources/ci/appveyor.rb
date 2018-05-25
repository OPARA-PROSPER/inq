# frozen_string_literal: true

require "okay/default"
require "okay/http"
require "how_is/sources"
require "how_is/sources/github/contributions"

module HowIs
  module Sources
    module CI
      # Fetches metadata about CI builds from appveyor.com.
      class Appveyor
        # TODO: Use start/end date.
        # @param repository [String] GitHub repository name, of the format user/repo.
        # @param start_date [String] Start date for the report being generated.
        # @param end_date [String] End date for the report being generated.
        def initialize(repository, start_date, end_date)
          @repository = repository
          @start_date = start_date
          @end_date = end_date
          @default_branch = Okay.default
        end

        # @return [String] The default branch name.
        def default_branch
          return @default_branch unless @default_branch.nil?

          contributions =
            HowIs::Sources::GitHub::Contributions.new(repository, nil, nil)

          @default_branch = contributions.default_branch
        end

        # Fetches builds for the default branch.
        #
        # @return [Hash] Builds for the default branch.
        def builds
          @builds ||= fetch_builds["builds"].map(&method(:normalize_build))
        rescue Net::HTTPServerException
          # It's not elegant, but it works™.
          []
        end

        private

        def normalize_build(build)
          build["started_at"] = DateTime.parse(build["created"])
          build["html_url"] = "https://ci.appveyor.com/project/#{@repository}/build/#{build['buildNumber']}"
          build
        end

        # Returns API result of /api/projects/:repository.
        #
        # @return [Hash] API results.
        def fetch_builds
          Okay::HTTP.get(
            "https://ci.appveyor.com/api/projects/#{@repository}/history",
            parameters: { "recordsNumber" => "100" },
            headers: {
              "Accept" => "application/json",
              "User-Agent" => HowIs::USER_AGENT,
            }
          ).or_raise!.from_json
        end
      end
    end
  end
end
