class SkipLogicFormField extends React.Component {
  constructor(props) {
    super();
    let skip = props.skipRules.length === 0 ? "dont_skip" : "skip";
    this.state = Object.assign({}, props, {skip: skip});
    this.skipOptionChanged = this.skipOptionChanged.bind(this);
  }

  skipOptionChanged(event) {
    this.setState({skip: event.target.value});
  }

  skipOptionTags() {
    const skipOptions = ["dont_skip", "skip"];
    return skipOptions.map((option) => (
      <option
        key={option}
        value={option}>
        {I18n.t(`form_item.skip_logic_options.${option}`)}
      </option>
    ));
  }

  render() {
    let selectProps = {
      className: "form-control skip-or-not",
      value: this.state.skip,
      onChange: this.skipOptionChanged
    };

    return (
      <div>
        <select {...selectProps}>
          {this.skipOptionTags()}
        </select>
        <SkipRuleSetFormField
          hide={this.state.skip === "dont_skip"}
          {...this.state} />
      </div>
    );
  }
}

SkipLogicFormField.propTypes = {
  skipRules: React.PropTypes.arrayOf(React.PropTypes.object).isRequired
};
