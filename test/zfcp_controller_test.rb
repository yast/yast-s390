#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast

Yast.import "ZFCPController"

describe "ZFCPController" do

  it "Activating disks" do
    expect(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/zfcp_host_configure '1' 1/).and_return(0)
    expect(Yast::ZFCPController).to_not receive(:ReportControllerActivationError)
    Yast::ZFCPController.ActivateDisk(1)
  end

  it "Getting all controllers" do
    data = [
      {"bus"=>"CCW", "bus_hwcfg"=>"ccw", "class_id"=>1, "detail"=>{"cu_model"=>3, "dev_model"=>3,
      "lcss"=>0}, "device"=>"zFCP controller", "device_id"=>268081, "drivers"=>[{"active"=>true,
      "modprobe"=>true, "modules"=>[["zfcp", ""]]}], "model"=>"IBM zFCP controller",
      "old_unique_key"=>"_AAN.6czr7zOIMz1", "resource"=>{"io"=>[{"active"=>true, "length"=>3,
      "mode"=>"rw", "start"=>63488}]}, "sub_class_id"=>0, "sub_device_id"=>268082,
      "sysfs_bus_id"=>"0.0.f800", "sysfs_id"=>"/devices/css0/0.0.000b/0.0.f800",
      "unique_key"=>"LfOP.AbUgA7O1gK4", "vendor"=>"IBM", "vendor_id"=>286721}, {"bus"=>"CCW",
      "bus_hwcfg"=>"ccw", "class_id"=>1, "detail"=>{"cu_model"=>3, "dev_model"=>3, "lcss"=>0},
      "device"=>"zFCP controller", "device_id"=>268081, "drivers"=>[{"active"=>true,
      "modprobe"=>true, "modules"=>[["zfcp", ""]]}], "model"=>"IBM zFCP controller",
      "old_unique_key"=>"_AAN.6czr7zOIMz1", "resource"=>{"io"=>[{"active"=>true, "length"=>3,
      "mode"=>"rw", "start"=>63744}]}, "sub_class_id"=>0, "sub_device_id"=>268082,
      "sysfs_bus_id"=>"0.0.f900", "sysfs_id"=>"/devices/css0/0.0.000c/0.0.f900",
      "unique_key"=>"D_tE.AbUgA7O1gK4", "vendor"=>"IBM", "vendor_id"=>286721}, {"bus"=>"CCW",
      "bus_hwcfg"=>"ccw", "class_id"=>1, "detail"=>{"cu_model"=>3, "dev_model"=>3, "lcss"=>0},
      "device"=>"zFCP controller", "device_id"=>268081, "drivers"=>[{"active"=>true,
      "modprobe"=>true, "modules"=>[["zfcp", ""]]}], "model"=>"IBM zFCP controller",
      "old_unique_key"=>"_AAN.6czr7zOIMz1", "resource"=>{"io"=>[{"active"=>true, "length"=>3,
      "mode"=>"rw", "start"=>64000}]}, "sub_class_id"=>0, "sub_device_id"=>268082,
      "sysfs_bus_id"=>"0.0.fa00", "sysfs_id"=>"/devices/css0/0.0.000d/0.0.fa00",
      "unique_key"=>"J+9e.AbUgA7O1gK4", "vendor"=>"IBM", "vendor_id"=>286721}, {"bus"=>"CCW",
      "bus_hwcfg"=>"ccw", "class_id"=>1, "detail"=>{"cu_model"=>3, "dev_model"=>3, "lcss"=>0},
      "device"=>"zFCP controller", "device_id"=>268081, "drivers"=>[{"active"=>true,
      "modprobe"=>true, "modules"=>[["zfcp", ""]]}], "model"=>"IBM zFCP controller",
      "old_unique_key"=>"_AAN.6czr7zOIMz1", "resource"=>{"io"=>[{"active"=>true, "length"=>3,
      "mode"=>"rw", "start"=>64512}]}, "sub_class_id"=>0, "sub_device_id"=>268082,
      "sysfs_bus_id"=>"0.0.fc00", "sysfs_id"=>"/devices/css0/0.0.000e/0.0.fc00",
      "unique_key"=>"1f8J.AbUgA7O1gK4", "vendor"=>"IBM", "vendor_id"=>286721}]
    expect(Yast::SCR).to receive(:Read).with(path(".probe.storage")).once.and_return(data)

    # Removing all fcp devices from blacklist
    expect(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/vmcp q v fcp/).and_return(
      "exit" => 0, 
      "stdout" => "FCP  F800 ON FCP   F807 CHPID 1C SUBCHANNEL = 000B\n  F800 TOKEN = 0000000362A42C00")
    expect(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/cio_ignore -r f800/).and_return(0)

    expect(Yast::ZFCPController.GetControllers()).to eq(
      [
        {"sysfs_bus_id"=>"0.0.f800"},
        {"sysfs_bus_id"=>"0.0.f900"},
        {"sysfs_bus_id"=>"0.0.fa00"},
        {"sysfs_bus_id"=>"0.0.fc00"}
      ]
    )
  end

  it "Importing devices and getting a device index" do
    import_data = { "devices"=>[{"controller_id" => "0.0.fa00"},
      {"controller_id" => "0.0.fc00"},
      {"controller_id" => "0.0.f800"},
      {"controller_id" => "0.0.f900"}]}

  end

end
