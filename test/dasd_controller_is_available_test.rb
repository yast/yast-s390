#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast

Yast.import "DASDController"


describe "DASDController" do

  it "IsAvailable returns true if .probe.disk contains DASDs" do

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

    expect(Yast::SCR).to receive(:Read).with(path(".probe.disk")).once.and_return(data)
    expect(Yast::DASDController.IsAvailable()).to eq(true)

  end

  it "writes dasd settings to target (formating disks)" do
    # bnc 928388

    data = { "devices" => [{"channel" => "0.0.0100", "diag" => false,
     "format" => true}], "format_unformatted" => true }

    allow(Yast::Mode).to receive(:normal).and_return(false)
    allow(Yast::Mode).to receive(:installation).and_return(true)
    allow(Yast::Mode).to receive(:autoinst).and_return(true)
    allow(Yast::DASDController).to receive(:ActivateDisk).and_return(0)
    expect(Yast::DASDController).to receive(:GetDeviceName).and_return("/dev/dasda")
    expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".process.start_shell"),
      "/sbin/dasdfmt -Y -P 1 -b 4096 -y -r 10 -m 10 -f '/dev/dasda'")

    expect(Yast::DASDController.Import(data)).to eq(true)
    expect(Yast::DASDController.Write).to eq(true)

  end

end
