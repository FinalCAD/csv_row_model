require 'spec_helper'

describe IntegerFormatValidator do
  let(:klass) do
    Class.new do
      include ActiveWarnings
      attr_accessor :string1
      warnings do
        validates :string1, integer_format: true
      end

      def self.name; "TestClass" end
    end
  end
  let(:instance) { klass.new }
  subject { instance.safe? }

  it_behaves_like "validated_types"

  context "proper Integer" do
    before { instance.string1 = "123" }
    it "is valid" do
      expect(subject).to eql true
    end

    it_behaves_like "allows_prefix_zero"
    it_behaves_like "allows_suffix_zero"
    it_behaves_like "allows_suffix_decimal_zero"
  end

  context "Float" do
    before { instance.string1 = "123.0000" }
    it "is valid" do
      expect(subject).to eql true
    end

    context "with decimals" do
      before { instance.string1 = "123.123" }
      it "is invalid" do
        expect(subject).to eql false
      end
    end

    context "with decimals that have zeros" do
      before { instance.string1 = "123.0001" }
      it "is invalid" do
        expect(subject).to eql false
      end
    end

    it_behaves_like "allows_zeros_with_decimal"
  end
end