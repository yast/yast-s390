# encoding: utf-8

module Yast
  class S390Client < Client
    def main
      # testedfiles: S390.ycp

      Yast.include self, "testsuite.rb"
      TESTSUITE_INIT([], nil)

      Yast.import "DASDController"

      DUMP("DASDController::GetModified")
      TEST(lambda { DASDController.GetModified }, [], nil)

      nil
    end
  end
end

Yast::S390Client.new.main
