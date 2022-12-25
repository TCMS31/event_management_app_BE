# frozen_string_literal: true

# Keeps list endpoints bounded.
#
# Every collection action used to run `SELECT * FROM events WHERE ...` with no
# LIMIT and serialize the whole result set. That is fine with the twelve rows a
# demo seeds and ruinous with a hundred thousand, so the window is now explicit
# and capped. The page metadata travels in headers, which keeps the response
# body a plain JSON array — the shape the React client already parses.
module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100

  private

  # Applies LIMIT/OFFSET and sets X-Total-Count / X-Page / X-Per-Page.
  def paginate(scope)
    write_pagination_headers(scope.reorder(nil).count(:all))

    scope.limit(per_page).offset((page - 1) * per_page)
  end

  def write_pagination_headers(total)
    response.set_header('X-Total-Count', total.to_s)
    response.set_header('X-Page', page.to_s)
    response.set_header('X-Per-Page', per_page.to_s)
  end

  def page
    @page ||= [params[:page].to_i, 1].max
  end

  def per_page
    @per_page ||= begin
      requested = params[:per_page].to_i
      requested = DEFAULT_PER_PAGE if requested <= 0
      [requested, MAX_PER_PAGE].min
    end
  end
end
