# frozen_string_literal: true

# Offset pagination, deliberately hand-rolled.
#
# It is forty lines and it never changes underneath an upgrade. A gem here would
# be a dependency with a moving API in exchange for arithmetic we can read.
module Pagination
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  # Wraps a page of records with everything a view needs to render controls.
  Page = Struct.new(:records, :current_page, :per_page, :total_count, keyword_init: true) do
    def total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    def first_page? = current_page <= 1
    def last_page?  = current_page >= total_pages
    def prev_page   = first_page? ? nil : current_page - 1
    def next_page   = last_page? ? nil : current_page + 1
    def offset      = (current_page - 1) * per_page
    def first_item  = total_count.zero? ? 0 : offset + 1
    def last_item   = [ offset + records.size, total_count ].min
    def many_pages? = total_pages > 1

    delegate :each, :map, :size, :empty?, :any?, to: :records
    include Enumerable
  end

  included do
    helper_method :paginate_params
  end

  private

  def paginate(relation, per_page: DEFAULT_PER_PAGE)
    per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
    total    = relation.limit(nil).offset(nil).count
    total    = total.size if total.is_a?(Hash) # grouped relations

    page = params[:page].to_i
    page = 1 if page < 1

    Page.new(
      records: relation.limit(per_page).offset((page - 1) * per_page).to_a,
      current_page: page,
      per_page: per_page,
      total_count: total
    )
  end

  # Preserves filters (search terms, tabs) when linking between pages.
  def paginate_params(page)
    request.query_parameters.merge(page: page)
  end
end
