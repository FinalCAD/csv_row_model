require 'spec_helper'

describe DateFormatValidator do
  let(:klass) do
    Class.new do
      include ActiveWarnings
      attr_accessor :string1
      warnings do
        validates :string1, date_format: true
      end

      def self.name; "TestClass" end
    end
  end
  let(:instance) { klass.new }
  subject { instance.safe? }

  it_behaves_like "validated_types"

  context "proper Date" do
    before { instance.string1 = "12/12/2012" }

    it "is valid" do
      expect(subject).to eql true
    end
  end
end