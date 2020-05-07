def expected_policy_behavior(policy:, policy_args: [], input:, output: nil, errors: {}, environment: {}, ignore_for: [])
  output ||= input
  schema = Paradocs::Schema.new do
    input.map do |key, value|
      instruction = ignore_for.include?(key) ? -> { field(key) } : -> { field(key).policy(*([policy] + policy_args)) }

      instance_exec &instruction
    end
  end

  if block_given? || output.nil?
    expect { schema.resolve(input, environment) }.to yield
  else
    result = schema.resolve(input, environment)
    expect(result.output).to eq(output)
    expect(result.errors).to eq(errors)
  end
end
