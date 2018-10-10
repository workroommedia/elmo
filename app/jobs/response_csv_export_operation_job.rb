# frozen_string_literal: true

class ResponseCsvExportOperationJob < OperationJob
  def perform(operation, search = nil)
    ability = Ability.new(user: operation.creator, mission: mission)
    result = generate_csv(responses(ability, search))
    operation_succeeded(result)
  rescue Search::ParseError => error
    operation_failed(error.to_s)
  end

  private

  def responses(ability, search)
    responses = Response.accessible_by(ability, :export)
    responses = search(responses, search, mission) if search.present?

    # Get the response, for export, but not paginated.
    # We deliberately don't eager load as that is handled in the Results::Csv::Generator class.
    responses.order(:created_at)
  end

  def search(responses, search)
    # do search, excluding excerpts
    Response.do_search(
      responses,
      search,
      {mission: mission},
      include_excerpts: false
    )
  end

  def generate_csv(responses)
    attachment = Results::Csv::Generator.new(responses).export
    timestamp = Time.zone.now.to_s(:filename_datetime)
    attachment_download_name = "elmo-#{mission.compact_name}-responses-#{timestamp}.csv"

    {attachment: attachment, attachment_download_name: attachment_download_name}
  end
end