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

    expect(Yast::ZFCPController.Import(import_data)).to eq(true)
    expect(Yast::ZFCPController.GetDeviceIndex("0.0.f800")).to eq(2)
  end

  it "Probing disk" do
    data = [
      {"bus"=>"SCSI", "bus_hwcfg"=>"scsi", "class_id"=>262,
        "detail"=>{"channel"=>0, "controller_id"=>"0.0.fa00", "fcp_lun"=>"0x4010400000000000", "host"=>0, "id"=>0,
          "lun"=>0, "wwpn"=>"0x500507630500873a"},
        "dev_name"=>"/dev/sda", "dev_name2"=>"/dev/sg0",
        "dev_names"=>["/dev/sda", "/dev/disk/by-path/ccw-0.0.fa00-zfcp-0x500507630500873a:0x4010400000000000"],
        "dev_num"=>{"major"=>8, "minor"=>0, "range"=>16, "type"=>"b"}, "device"=>"2107900",
        "driver"=>"zfcp", "driver_module"=>"zfcp", "model"=>"IBM 2107900", "old_unique_key"=>"IWc2.6bauZ5mFTd6",
        "parent_unique_key"=>"J+9e.AbUgA7O1gK4",
        "resource"=>{"disk_log_geo"=>[{"cylinders"=>10240, "heads"=>64, "sectors"=>32}],
          "fc"=>[{"fcp_lun"=>4616259986798936064, "wwpn"=>5766023019784865594}],
          "size"=>[{"unit"=>"sectors", "x"=>20971520, "y"=>512}]},
        "rev"=>".107", "sub_class_id"=>0, "sysfs_bus_id"=>"0:0:0:1073758224", "sysfs_id"=>"/class/block/sda",
        "unique_key"=>"45Yl.GSrOUlvrrQE", "vendor"=>"IBM"},
      {"bus"=>"SCSI", "bus_hwcfg"=>"scsi", "class_id"=>262,
        "detail"=>{"channel"=>0, "controller_id"=>"0.0.fa00", "fcp_lun"=>"0x401340ec00000000", "host"=>0, "id"=>0,
          "lun"=>0, "wwpn"=>"0x500507630500873a"},
        "dev_name"=>"/dev/sdb", "dev_name2"=>"/dev/sg1",
        "dev_names"=>["/dev/sdb", "/dev/disk/by-path/ccw-0.0.fa00-zfcp-0x500507630500873a:0x401340ec00000000"],
        "dev_num"=>{"major"=>8, "minor"=>16, "range"=>16, "type"=>"b"}, "device"=>"2107900",
        "driver"=>"zfcp", "driver_module"=>"zfcp", "model"=>"IBM 2107900", "old_unique_key"=>"BC8F.foOOC_QWNz0",
        "parent_unique_key"=>"J+9e.AbUgA7O1gK4",
        "resource"=>{"disk_log_geo"=>[{"cylinders"=>1011, "heads"=>34, "sectors"=>61}],
          "fc"=>[{"fcp_lun"=>4617105425341349888, "wwpn"=>5766023019784865594}],
          "size"=>[{"unit"=>"sectors", "x"=>2097152, "y"=>512}]},
        "rev"=>".107", "sub_class_id"=>0, "sysfs_bus_id"=>"0:0:0:1089224723", "sysfs_id"=>"/class/block/sdb",
        "unique_key"=>"XGop.pffu6ea6mm8", "vendor"=>"IBM"}
    ]
    expect(Yast::SCR).to receive(:Read).with(path(".probe.disk")).once.and_return(data)
    expect(Yast::SCR).to receive(:Read).with(path(".probe.tape")).once.and_return([])

    expect(Yast::ZFCPController.ProbeDisks()).to eq(nil)
    expect(Yast::ZFCPController.devices()).to eq(
      {0=>{"detail"=>{"channel"=>0, "controller_id"=>"0.0.fa00",
         "fcp_lun"=>"0x4010400000000000", "host"=>0, "id"=>0, "lun"=>0, "wwpn"=>"0x500507630500873a"},
         "dev_name"=>"/dev/sda", "device"=>"2107900", "vendor"=>"IBM"},
       1=>{"detail"=>{"channel"=>0, "controller_id"=>"0.0.fa00",
         "fcp_lun"=>"0x401340ec00000000", "host"=>0, "id"=>0, "lun"=>0,
         "wwpn"=>"0x500507630500873a"}, "dev_name"=>"/dev/sdb", "device"=>"2107900", "vendor"=>"IBM"}})
  end

  it "Filtering devices" do
    import_data = { "devices"=>[{"controller_id" => "0.0.fa00"},
      {"controller_id" => "0.0.fb00"},
      {"controller_id" => "0.0.fc00"},
      {"controller_id" => "0.0.f800"},
      {"controller_id" => "0.0.f900"}]}

    expect(Yast::ZFCPController.Import(import_data)).to eq(true)
    ZFCPController.filter_max = ZFCPController.FormatChannel("0.0.FA00")
    ZFCPController.filter_min = ZFCPController.FormatChannel("0.0.f900")
    expect(Yast::ZFCPController.GetFilteredDevices()).to eq({
      0=>{"detail"=>{"controller_id"=>"0.0.fa00", "wwpn"=>"", "fcp_lun"=>""}},
      4=>{"detail"=>{"controller_id"=>"0.0.f900", "wwpn"=>"", "fcp_lun"=>""}}})
  end

end
