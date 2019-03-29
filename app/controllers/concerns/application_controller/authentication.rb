# frozen_string_literal: true

# ApplicationController methods related to authentication
module Concerns::ApplicationController::Authentication
  extend ActiveSupport::Concern

  attr_reader :current_user, :current_mission

  def load_current_mission
    # If we're in admin mode, the current mission is nil and
    # we need to set the user's current mission to nil also
    if mission_mode? && params[:mission_name].present?
      # Look up the current mission based on the mission_id.
      # This will return 404 immediately if the mission was specified but isn't found.
      # This helps out people typing in the URL (esp. ODK users)
      # by letting them know permission is not an issue.
      @current_mission = Mission.with_compact_name(params[:mission_name])

      # save the current mission in the session so we can remember it if the user goes into admin mode
      session[:last_mission_name] = @current_mission.try(:compact_name)
    else
      @current_mission = nil
    end
  end

  # Determines the user and saves in the @current_user var.
  def load_current_user
    # If user already logged in via Authlogic, we are done.
    if (user_session = UserSession.find) && user_session.user

      @current_user = user_session.user

    # If the direct_auth parameter is set (usually set in the routes file), we
    # expect the request to provide its own authentication using e.g. basic
    # auth, or no auth.
    elsif params[:direct_auth]
      # HTTP Basic authenticated request.
      @current_user = authenticate_with_http_basic do |login, password|
        # Use eager loading.
        User.includes(:assignments).find_with_credentials(login, password)
      end

      return request_http_basic_authentication unless @current_user

      return render(plain: "USER_INACTIVE", status: :unauthorized) unless @current_user.active?
    else
      # If we get here, nothing worked!
      @current_user = nil
    end
  end

  # get the current user's ability. not cached because it's volatile!
  def current_ability
    Ability.new(user: current_user, mode: current_mode, mission: current_mission)
  end

  # Loads missions accessible to the current ability, or [] if no current user, for use in the view.
  def load_accessible_missions
    @accessible_missions = Mission.accessible_by(current_ability, :switch_to).sorted_by_name
  end

  # don't count automatic timer-based requests for resetting the logout timer
  # all automatic timer-based should set the 'auto' parameter
  # (This is an override for a method defined by AuthLogic)
  def last_request_update_allowed?
    params[:auto].nil?
  end
end
