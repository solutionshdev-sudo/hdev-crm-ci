class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact if permitted_params.key?(:limits)
    permitted_params[:captain_models] = permitted_params[:captain_models].to_h.compact_blank.presence if permitted_params.key?(:captain_models)
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    redirect_back(fallback_location: [namespace, requested_resource], notice: I18n.t('super_admin.flash.seeding_triggered'))
  end

  def reset_cache
    requested_resource.reset_cache_keys
    redirect_back(fallback_location: [namespace, requested_resource], notice: I18n.t('super_admin.flash.cache_cleared'))
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    redirect_back(fallback_location: [namespace, requested_resource], notice: I18n.t('super_admin.flash.account_deletion_in_progress'))
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
