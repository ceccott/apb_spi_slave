# APB SPI Slave 

[!! WORK IN PROGRESS !!]

This is an implementation of a simple SPI slave. 
An external microcontroller can use the SPI slave to access the memory of the SoC where this IP is
instantiated. The SPI slave uses the APB bus to access the memory of the target
SoC.

It contains dual-clock FIFOs to perform the clock domain crossing from SPI to
the SoC (APB) domain.

This is a fork of [obi_spi_slave](https://github.com/esl-epfl/obi_spi_slave)
