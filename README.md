# usb_cdl
A full SoC peripheral module contains both the SoC Bus interface module and the functional modules that execute the peripheral's communication standard. In this overall design, the SoC bus interface is a more fully capable AHB bus, and the peripheral's communication standard is a focused subset of USB 1.1 (Full-Speed). The USB standard is focused solely on supporting the basic Bulk Transfer type under the USB 1.1 standard (No USB startup/bus enumeration or other aspects of the standard need to be directly handled in this design). SoC should be able to handle endpoint-based communication between the device and the host. This SoC runs on a 100MHz clock and the data is sent 12MHz.

AHB Subordinate: Connects SoC and USB support for data transfers (Joe)

USB RX: Receives and validates data sent from host (Steven)

Data Buffer: Handles the storing and reading of up to 64 data bytes between modules (Amy)

USB TX: Sends data packets from endpoint  to the host (Amy)

Modules created by Amy Basca, Steven Li, and Joe Tran.


