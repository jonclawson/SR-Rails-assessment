class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # PaperTrail: Track who made changes
  before_action :set_paper_trail_whodunnit

  private

  def user_for_paper_trail
    Current.user&.id
  end
end
