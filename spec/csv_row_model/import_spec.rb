require 'spec_helper'

describe CsvRowModel::Import do
  describe "instance" do
    let(:source_row) { %w[1.01 b] }
    let(:options) { {} }
    let(:import_model_klass) { BasicImportModel }
    let(:instance) { import_model_klass.new(source_row, options) }

    describe "#initialize" do
      subject { instance }

      context "should set the child" do
        let(:parent_instance) { BasicModel.new }
        let(:options) { { parent:  parent_instance } }
        specify { expect(subject.child?).to eql true }
      end
    end

    describe "#inspect" do
      subject { instance.inspect }
      it("works") { subject }
    end

    describe "#mapped_row" do
      subject { instance.mapped_row }
      it "returns a map of `column_name => source_row[index_of_column_name]" do
        expect(subject).to eql(string1: "1.01", string2: "b")
      end
    end

    describe "#csv_string_model" do
      subject { instance.csv_string_model }
      it "returns csv_string_model with methods working" do
        expect(subject.string1).to eql "1.01"
        expect(subject.string2).to eql "b"
      end

      context "with format_cell" do
        it "should format_cell first" do
          expect(import_model_klass).to receive(:format_cell).with("1.01", :string1, 0).and_return(nil)
          expect(import_model_klass).to receive(:format_cell).with("b", :string2, 1).and_return(nil)
          expect(subject.string1).to eql nil
          expect(subject.string2).to eql nil
        end
      end
    end

    describe "#valid?" do
      subject { instance.valid? }
      let(:import_model_klass) { ImportModelWithValidations }

      it "works" do
        expect(subject).to eql true
      end

      context "with empty row" do
        let(:source_row) { %w[] }

        it "works" do
          expect(subject).to eql false
        end
      end

      context "with custom class" do
        let(:import_model_klass) do
          Class.new do
            include CsvRowModel::Model
            include CsvRowModel::Import

            column :id

            def self.name; "TwoLayerValid" end
          end
        end

        context "overriding validations" do
          before do
            import_model_klass.instance_eval do
              validates :id, length: { minimum: 5 }
              csv_string_model do
                validates :id, presence: true
              end
            end
          end

          it "takes the csv_string_model_class validation first then the row_model validation" do
            expect(subject).to eql false
            expect(instance.errors.full_messages).to eql ["Id is too short (minimum is 5 characters)"]
          end

          context "with empty row" do
            let(:source_row) { [''] }

            it "just shows the csv_string_model_class validation" do
              expect(subject).to eql false
              expect(instance.errors.full_messages).to eql ["Id can't be blank"]
            end
          end
        end

        context "with warnings" do
          before do
            import_model_klass.instance_eval do
              warnings do
                validates :id, length: { minimum: 5 }
              end
              csv_string_model do
                warnings do
                  validates :id, presence: true
                end
              end
            end
          end

          context "with empty row" do
            let(:source_row) { [''] }

            it "just shows the csv_string_model_class validation" do
              expect(subject).to eql true
              expect(instance.safe?).to eql false
              expect(instance.warnings.full_messages).to eql ["Id can't be blank"]
            end
          end
        end
      end
    end

    describe "#free_previous" do
      let(:options) { { previous: import_model_klass.new([]) } }

      subject { instance.free_previous }

      it "makes previous nil" do
        expect(instance.previous).to_not eql nil
        subject
        expect(instance.previous).to eql nil
      end
    end
  end
end
