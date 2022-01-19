require "yaml"

module Y2S390
  class HwinfoReader
    include Singleton

    def for_device(id, force_probing: false)
      reset if force_probing

      data[id]
    end

    def reset
      @data = nil
    end

    def data
      @data ||= data_from_hwinfo
    end

  private

    def disks
      if mock_filename
        load_data(mock_filename)
      else
        Yast::SCR.Read(Yast.path(".probe.disk")) || []
      end
    end

    def mock_filename
      ENV["S390_MOCKING"] ? "test/data/probe_disk_dasd.yml" : ENV["YAST2_S390_PROBE_DISK"]
    end

    def data_from_hwinfo
      disks.each_with_object({}) do |disk, hash|
        hw_data = struct_for(disk)
        hash[hw_data.sysfs_bus_id] = hw_data
      end
    end

    def struct_for(hash_value)
      hash_value.each_with_object(OpenStruct.new) do |(k, v), data|
        value = if k == "io" && v.is_a?(Array)
          v.first.is_a?(Hash) ? v.map { |e| struct_for(e) } : v
        else
          v.is_a?(Hash) ? struct_for(v) : v
        end

        data.public_send("#{k}=", value)
      end
    end

    def load_data(name)
      YAML.safe_load(File.read(name))
    end
  end
end
