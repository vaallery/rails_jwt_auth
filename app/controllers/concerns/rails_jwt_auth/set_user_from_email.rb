module RailsJwtAuth
  module SetUserFromEmail
    def set_user_from_email
      email = (password_create_params[RailsJwtAuth.email_field_name] || '').strip
      email.downcase! if RailsJwtAuth.downcase_auth_field

      if email.blank?
        return render_422(RailsJwtAuth.email_field_name => [{error: :blank}])
      elsif !email.match?(RailsJwtAuth.email_regex)
        return render_422(RailsJwtAuth.email_field_name => [{error: :format}])
      end

      @user = RailsJwtAuth.model.where(RailsJwtAuth.email_field_name => email).first
    end
  end
end
