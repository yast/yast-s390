# YaST - The S390 Configuration Module

[![Workflow Status](https://github.com/yast/yast-s390/workflows/CI/badge.svg?branch=master)](
https://github.com/yast/yast-s390/actions?query=branch%3Amaster)
[![Jenkins Status](https://ci.opensuse.org/buildStatus/icon?job=yast-yast-s390-master)](
https://ci.opensuse.org/view/Yast/job/yast-yast-s390-master/)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-s390.svg)](https://coveralls.io/r/yast/yast-s390?branch=master)

## Resources

For s390 development these resources are used:

- https://www.ibm.com/developerworks/linux/linux390/documentation_dev.html
- https://www.ibm.com/developerworks/linux/linux390/documentation_suse.html (for released products)

## Development

On your development laptop you will normally see no s390 specific devices.
In the `test/` directory there are mock data that can be used for UI
development. Set an environment variable to override the
`SCR.Read(.probe.disk)` call:

    YAST2_S390_PROBE_DISK=test/data/probe_disk_dasd.yml rake run"[dasd]"

or

    YAST2_S390_PROBE_DISK=test/data/probe_disk.yml      rake run"[zfcp]"

