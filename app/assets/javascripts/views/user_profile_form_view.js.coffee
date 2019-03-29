class ELMO.Views.UserProfileFormView extends ELMO.Views.ApplicationView
  el: "form.user_form"

  events:
    "change select#user_gender": "toggle_custom_gender_visibility"
    "change select#user_reset_password_method": "toggle_password_fields"

  initialize: (params) ->
    @params = params || {}
    @init_user_group_select()
    @toggle_custom_gender_visibility()

  init_user_group_select: ->
    @$("#user_user_group_ids").select2
      tags: true
      templateResult: @format_suggestions
      ajax:
        url: @params.user_group_options_url
        dataType: "json"
        delay: 250
        cache: true
        processResults: (data) -> {results: data}

  format_suggestions: (item) ->
    if item.id == item.text
      return $('<li><i class="fa fa-fw fa-plus-circle"></i>' + item.text +
      ' <span class="details create_new">[' + I18n.t('user_group.new_group') + ']</span>' + '</li>')
    else
      return item.text

  toggle_custom_gender_visibility: (event) ->
    select_value = @$("select#user_gender").val()
    if select_value == "specify"
      @$("div.user_gender_custom").show()
    else
      @$("input#user_gender_custom").val("")
      @$("div.user_gender_custom").hide()

  toggle_password_fields: (event) ->
    select_value = @$("select#user_reset_password_method").val()
    @$(".password-fields").toggleClass("hide", select_value != "enter" && select_value != "enter_and_show")
