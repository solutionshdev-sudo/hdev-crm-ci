class UpdateWidgetColorDefaultToHdevGreen < ActiveRecord::Migration[7.1]
  OLD_COLOR = '#1f93ff'.freeze
  NEW_COLOR = '#00875A'.freeze

  def up
    change_column_default :channel_web_widgets, :widget_color, from: OLD_COLOR, to: NEW_COLOR
    # Widgets criados antes do rebrand que ficaram na cor padrao antiga
    Channel::WebWidget.where(widget_color: OLD_COLOR).update_all(widget_color: NEW_COLOR)
  end

  def down
    change_column_default :channel_web_widgets, :widget_color, from: NEW_COLOR, to: OLD_COLOR
  end
end
