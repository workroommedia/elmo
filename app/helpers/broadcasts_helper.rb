module BroadcastsHelper
  def broadcasts_index_links(broadcasts)
    if can?(:create, Broadcast) && !offline_mode?
      [link_to(t("broadcast.send_broadcast"), new_broadcast_path)]
    else
      []
    end
  end

  def broadcasts_index_fields
    %w[recipients medium sent_at errors body]
  end

  def format_broadcasts_field(broadcast, field)
    case field
    when "recipients"
      if broadcast.recipient_selection == "specific"
        users = (c = broadcast.recipient_user_count) > 0 ? I18n.t("broadcast.user_count", count: c) : nil
        groups = (c = broadcast.recipient_group_count) > 0 ? I18n.t("broadcast.group_count", count: c) : nil
        [users, groups].compact.join(", ")
      else
        t("broadcast.recipient_selection_options.#{broadcast.recipient_selection}")
      end
    when "medium"
      t("broadcast.mediums.names." + broadcast.medium)
    when "body"
      link_to(truncate(broadcast.body, :length => 100), broadcast_path(broadcast), :title => t("common.view"))
    when "sent_at"
      if broadcast.sent_at.present?
        l(broadcast.sent_at)
      else
        t("common.pending")
      end
    when "errors"
      tbool(!broadcast.send_errors.blank?)
    else
      broadcast.send(field)
    end
  end
end
