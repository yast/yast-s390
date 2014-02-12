#!/usr/bin/rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast

Yast.import "DASDController"


describe "DASDController#IsAvailable" do


  it "configures snapper" do

    data = [
      { "bus" => "CCW", "bus_hwcfg" => "ccw", "class_id" => 262, "detail" => {
      "cu_model" => 233, "dev_model" => 10, "lcss" => 0 }, "device" => "DASD",
      "device_id" => 276880, "drivers" => [ { "active" => true, "modprobe" =>
      true, "modules" => [ [ "dasd_eckd_mod", "" ] ] } ], "model" => "IBM
      DASD", "old_unique_key" => "amWp.rOENMk3aQ50", "prog_if" => 1,
      "resource" => { "io" => [ { "active" => false, "length" => 1, "mode" =>
      "rw", "start" => 352 } ] }, "sub_class_id" => 0, "sub_device_id" =>
      275344, "sysfs_bus_id" => "0.0.0160", "sysfs_id" =>
      "/devices/css0/0.0.0001/0.0.0160", "unique_key" => "3VmV.ALFATSt_U8F",
      "vendor" => "IBM", "vendor_id" => 286721 }
    ]

    Yast::SCR.stub(:Read).with(path(".probe.disk")).once.and_return(data)

    expect(Yast::DASDController.IsAvailable()).to be_true

  end


end
