require "y2s390/dasd_actions/base"

module Y2S390
  module DasdActions
    class Activate < Base
      def run
        unformatted_disks = []

        selected.each do |dasd|
          unformatted_disks << dasd if activate(dasd) == 8 # 8 means disk is not formatted
        end

        # for autoinst, format unformatted disks later
        if format_now?(unformatted_disks)
          devices = unformatted_disks.each_with_object([]) { |d, arr| arr << d if device_for!(d) }
          controller.FormatDisks(devices)
          devices.each { |d| activate(d) }
        end

        controller.ProbeDisks

        true
      end

    private

      # Convenience method for checking if the activated DASD without format need to be formatted
      # now or not.
      #
      # @param unformatted_disks [Array<Dasd>]
      def format_now?(unformatted_disks)
        return false if auto_mode? || unformatted_disks.empty?

        popup = if unformatted_disks.size == 1
          format(_("Device %s is not formatted. Format device now?"), unformatted_disks.first.id)
        else
          format(_("There are %s unformatted devices. Format them now?"),
            unformatted_disks.size)
        end

        Yast::Popup.ContinueCancel(popup)
      end

      def device_for!(dasd)
        # We need to set it before format the disk
        name = dasd.device_name = dasd.sys_device_name
        Yast::Popup.Error(format(_("Couldn't find device for channel %s."), dasd.id)) if !name

        name
      end

      # Convenience method for activating a DASD device
      #
      # @param dasd [Dasd] device to be activated
      # @return [Boolean] whether the device was activated or not
      def activate(dasd)
        controller.ActivateDisk(dasd.id, !!dasd.diag_wanted)
      end
    end
  end
end
