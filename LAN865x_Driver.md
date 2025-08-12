
# LAN865x Linux Kernel Driver – Overview

---

## Device Tree (.dts) Differences  
**lan966x-pcb8291.dts** vs. **lan966x-pcb8291.org.dts**

The main differences between the two device trees relate to *additional support for SPI-connected LAN865x MAC-PHY devices* in `lan966x-pcb8291.lan865x.dts`.

**Key Additions in `lan966x-pcb8291.dts`**:
```powershell
&flx2 {
    compatible = "microchip,lan966x-flexcom";
    ...
    spi2: spi@400 {
        ...
        eth7: lan865x@0{
            compatible = "microchip,lan8651", "microchip,lan8650";
            reg = <0>; /* CE0 */
            enable-gpios = <&gpio 35 0x6>; /* Output High, Single Ended, Open-Drain*/
            interrupt-parent = <&gpio>;
            interrupts = <36 0x2>; /* 0x2 - falling edge trigger */
            local-mac-address = [04 05 06 01 02 03];
            spi-max-frequency = <15000000>;
            status = "okay";
        };
    };
};
```

- **Additional SPI Pinmux**:
```powershell
	fc2_b_pins: fc2-b-pins {
		/* SCK, MISO, MOSI*/  //DT: check on order required from driver
		pins = "GPIO_43", "GPIO_44", "GPIO_45";
		function = "fc2_b";
	};
```

- Rest of the DTS remains largely identical.

---

## How Device Tree Information Is Used in the LAN865x Linux Kernel Driver

### 1. Device Tree Matching & Probe
- The driver matches `compatible = "microchip,lan8650"` or `"microchip,lan8651"`.
- On match, the `probe()` function is called for the SPI device.

### 2. SPI and GPIO Setup
- **`reg`** → SPI chip select  
- **`enable-gpios`** → Enables/powers MAC-PHY  
- **`interrupts`** → Configures interrupt handling  
- **`spi-max-frequency`** → Applied to SPI setup  
- **Pinmux (`fc2_b_pins`)** ensures SCK, MISO, MOSI are routed to correct pins.

### 3. MAC Address Handling
- Reads `local-mac-address` from DT.  
- Falls back to a random address if absent.

### 4. Activation
- `status = "okay"` is required for driver to bind.

---

## Detailed DTS Entry Explanation

### `eth7: lan865x@0`
| Property            | Purpose                                           |
|---------------------|---------------------------------------------------|
| `compatible`        | Matches device to correct kernel driver           |
| `reg`               | SPI chip select line                              |
| `enable-gpios`      | Power/reset pin control                           |
| `interrupt-parent` & `interrupts` | IRQ GPIO and trigger edge            |
| `local-mac-address` | Fixed MAC for network identity                     |
| `spi-max-frequency` | Max SPI clock rate                                |
| `status`            | Enable/disable node                               |

### `fc2_b_pins`
- Assigns physical pins to the SPI signals for the LAN865x interface.

---

## High-Level Overview of LAN865x Linux Kernel Driver

### Function
- Implements a MAC-PHY driver for Microchip 10BASE‑T1S devices (LAN8650/8651).
- Communicates exclusively via SPI using OA-TC6 framing protocol.

### Initialization Flow
1. **DT Match** → `probe()` runs.
2. Allocate `net_device`.
3. Initialize SPI and `oa_tc6` transport.
4. Apply hardware fixups and ZARFE setting.
5. Read/set MAC address.
6. Register network device.

### Data Path
- **TX**: Ethernet frames are split into OA‑TC6 SPI chunks.  
- **RX**: Chunks parsed, reassembled, passed to networking stack.

### Interrupt Handling
- Triggered via GPIO-based IRQ from DT.
- Wakes driver SPI thread to handle events.

### Device Tree Integration
- GPIO, IRQ, SPI speed, and MAC all come from DT values.
- Pinmux automatically handled by Linux pinctrl subsystem.

### Extensibility
- For new boards, only DTS entry adjustments are needed.

---

## Summary Table – DTS Entries

| DTS Entry                  | Used for (Driver)                 | Effect                                                                 |
|----------------------------|------------------------------------|-------------------------------------------------------------------------|
| `compatible`               | DT matching                        | Ensures driver binds to hardware                                       |
| `reg`                      | SPI CS number                      | Identifies device on SPI bus                                            |
| `enable-gpios`              | GPIO control                       | Powers/resets MAC-PHY                                                   |
| `interrupts`               | IRQ line                           | Handles asynchronous events                                             |
| `local-mac-address`        | MAC address                        | Sets device network identity                                            |
| `spi-max-frequency`        | SPI speed limit                    | Safe communication speed                                                |
| `status`                   | Node enable                        | Controls whether driver probes                                          |
| `fc2_b_pins`               | Pinmux config                      | Maps SPI SCK/MISO/MOSI to physical pins                                 |

---

## Conclusion
The LAN865x kernel driver is a **device tree–driven network driver** for Microchip’s SPI‑attached 10BASE‑T1S MAC‑PHY devices. All hardware-specific parameters are declared in the DTS, allowing simple adaptation to new boards without changing driver source code.
