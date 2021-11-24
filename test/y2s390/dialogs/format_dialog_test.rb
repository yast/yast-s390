require_relative "../../test_helper.rb"

require "y2s390"
require "y2s390/dialogs/format_dialog"

describe Y2S390::Dialogs::FormatDialog do
  subject { described_class.new(selected) }

  let(:selected) { Y2S390::DasdsCollection.new([dasd0150]) }
  let(:dasd0150) { Y2S390::Dasd.new("0.0.0150") }

  def mock_ui_events(*events)
    allow(Yast::UI).to receive(:UserInput).and_return(*events)
  end

  before do
    mock_ui_events(:timeout)
  end

  describe "#user_input" do
    it "waits 1 second for input" do
      expect(Yast::UI).to receive(:TimeoutUserInput).with(1000)

      subject.user_input
    end
  end

  describe "#.new" do
    it "initializes the dasds with the given DasdsCollection" do
      expect(subject.dasds).to eq(selected)
    end

    it "initializes a FormatProcess with the given dasds" do
      expect(Y2S390::FormatProcess).to receive(:new).with(selected)
      subject
    end
  end

  describe "#run" do
    let(:running) { true }
    let(:status) { 0 }
    let(:fmt_process) do
      instance_double("Y2S390::FmtProcess", running?: running, start: true, status: status,
                      initialize_summary: true, update_summary: true)
    end

    before do
      allow(subject).to receive(:create_dialog)
      allow(subject).to receive(:close_dialog)
      allow(subject).to receive(:update_progress)
      allow(subject).to receive(:wait_for_update)

      allow(fmt_process).to receive(:running?).and_return(true, true, true, false)
      subject.fmt_process = fmt_process
    end

    it "starts a format process with the selected DASDs" do
      expect(fmt_process).to receive(:start)

      subject.run
    end

    context "when the process is not running after 0.2 seconds of waiting" do
      before do
        allow(fmt_process).to receive(:running?).and_return(false)
      end

      it "reports a format failed error" do
        expect(subject).to receive(:report_format_failed).with(subject.fmt_process)

        subject.run
      end

      it "returns nil" do
      end
    end

    context "when the process is started correctly" do
      it "creates the format dialogs" do
        expect(subject).to receive(:create_dialog)
        subject.run
      end

      it "initializes the FmtProcess summary" do
        expect(fmt_process).to receive(:initialize_summary)
        subject.run
      end

      context "while the process is running" do
        it "update the fmt process summary according to the dasdfmt output" do
          expect(fmt_process).to receive(:update_summary).twice
          subject.run
        end

        it "updates the dialog progress" do
          expect(subject).to receive(:update_progress).twice
          subject.run
        end
      end

      it "closes the format dialogs" do
        expect(subject).to receive(:close_dialog)
        subject.run
      end

      context "when the FmtProcess finishs" do
        let(:status) { 1 }

        it "reports a format failed error if the status of the process is not 0" do
          expect(subject).to receive(:report_format_failed).with(subject.fmt_process)

          subject.run
        end
      end

      it "returns :refresh" do
        expect(subject.run).to eq(:refresh)
      end
    end
  end
end
