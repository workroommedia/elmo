class DisplayLogicFormField extends React.Component {
  constructor(props) {
    super();
    this.state = props;
    this.displayIfChanged = this.displayIfChanged.bind(this);
  }

  displayIfChanged(event) {
    let value = event.target.value;
    this.setState({displayIf: value});
  }

  displayIfOptionTags() {
    const displayIfOptions = ["always", "all_met", "any_met"];
    return displayIfOptions.map((option) => (
      <option
        key={option}
        value={option}>
        {I18n.t(`form_item.display_if_options.${option}`)}
      </option>
    ));
  }

  render() {
    // Display logic conditions can't reference self, as that doesn't make sense.
    let refableQings = this.state.refableQings.slice(0, -1);

    if (refableQings.length === 0) {
      return (
        <div>
          {I18n.t("condition.no_refable_qings")}
        </div>
      );
    } else {
      let displayIfProps = {
        className: "form-control",
        name: "questioning[display_if]",
        id: "questioning_display_logic",
        value: this.state.displayIf,
        onChange: this.displayIfChanged
      };
      let conditionSetProps = {
        conditions: this.state.displayConditions,
        conditionableId: this.state.id,
        conditionableType: "FormItem",
        refableQings: refableQings,
        formId: this.state.formId,
        hide: this.state.displayIf === "always",
        namePrefix: "questioning[display_conditions_attributes]"
      };

      return (
        <div>
          <select {...displayIfProps}>
            {this.displayIfOptionTags()}
          </select>
          <ConditionSetFormField {...conditionSetProps} />
        </div>
      );
    }
  }
}
