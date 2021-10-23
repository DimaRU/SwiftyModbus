//
//  SwiftyModbusResult.swift
//  
//
//  Created by Dmitriy Borovikov on 13.08.2021.
//

import Foundation
import CModbus

fileprivate let errorValue: Int32 = -1

/// Libmodbus wrapper class with Result
public class SwiftyModbusResult {
    /// libmodbus error
    public struct ModbusError: Error {
        public let message: String
        public let errno: Int32
    }

    /// Error recovery options for setErrorRecovery function
    public struct ErrorRecoveryMode: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        public static let recoveryNone     = ErrorRecoveryMode(rawValue: MODBUS_ERROR_RECOVERY_NONE.rawValue)
        public static let recoveryLink     = ErrorRecoveryMode(rawValue: MODBUS_ERROR_RECOVERY_LINK.rawValue)
        public static let recoveryProtocol = ErrorRecoveryMode(rawValue: MODBUS_ERROR_RECOVERY_PROTOCOL.rawValue)
    }

    private var modbus: OpaquePointer

    /// Create a SwiftyModbus class for TCP Protocol
    /// - Parameters:
    ///   - address: IP address or host name
    ///   - port: port number to connect to
    public init(address: String, port: Int) {
        modbus = modbus_new_tcp_pi(address, String(port))
    }
    
    deinit {
        modbus_free(modbus);
    }
    
    /// Set debug flag of the context. When true, many verbose messages are displayed on stdout and stderr.
    public var debugMode = false {
        didSet {
            modbus_set_debug(modbus, debugMode ? 1:0);
        }
    }
    
    /// Set the slave number
    /// - Parameter slave: slave number (from 1 to 247) or 0xFF (MODBUS_TCP_SLAVE)
    public func setSlave(_ slave: Int32) {
        modbus_set_slave(self.modbus, slave)
    }

    /// Establish a connection to a Modbus server
    /// - Returns: esult<Void, ModbusError>
    public func connect() -> Result<Void, ModbusError> {
        guard modbus_connect(modbus) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }

    ///  Close the connection established
    public func disconnect() {
        modbus_close(self.modbus)
    }
    
    /// Set socket of the modbus context
    /// - Parameter socket: socket handle
    public func setSocket(socket: Int32) {
        modbus_set_socket(modbus, socket)
    }
    
    /// Get socket of the modbus context
    /// - Returns: socket handle
    public func getSocket() -> Int32 {
        modbus_get_socket(modbus)
    }
    
    /// Get/set the timeout TimeInterval used to wait for a response and connect
    public var responseTimeout: TimeInterval {
        get {
            var sec: UInt32 = 0
            var usec: UInt32 = 0
            modbus_get_response_timeout(modbus, &sec, &usec)
            return toTimerInterval(sec: sec, usec: usec)
        }
        set {
            let (sec, usec) = toSecUSec(timeInterval: newValue)
            modbus_set_response_timeout(modbus, sec, usec)
        }
    }
    
    /// Get/set the timeout interval between two consecutive bytes of the same message
    public var byteTimeout: TimeInterval {
        get {
            var sec: UInt32 = 0
            var usec: UInt32 = 0
            modbus_get_byte_timeout(modbus, &sec, &usec)
            return toTimerInterval(sec: sec, usec: usec)
        }
        set {
            let (sec, usec) = toSecUSec(timeInterval: newValue)
            modbus_set_byte_timeout(modbus, sec, usec)
        }
    }
    
    /// Retrieve the current header length
    /// - Returns: header length from the backend
    public var headerLength: Int32 {
        get {
            modbus_get_header_length(modbus)
        }
    }
    
    /// Flush non-transmitted data and discard data received but not read
    /// - Returns: Result<Void, ModbusError>
    public func flush() -> Result<Void, ModbusError> {
        guard modbus_flush(self.modbus) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }
    
    /// Set the error recovery mode to apply when the connection fails or the byte received is not expected.
    /// - Parameter mode: ErrorRecoveryMode optionSet
    public func setErrorRecovery(mode: ErrorRecoveryMode) -> Result<Void, ModbusError> {
        if modbus_set_error_recovery(self.modbus, modbus_error_recovery_mode(rawValue: mode.rawValue)) == errorValue {
            return .failure(modbusError())
        }
        return .success(())
    }

    /// Read the status of the bits (coils) to the address of the remote device.
    /// The function uses the Modbus function code 0x01 (read coil status).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the bits (coils)
    /// - Returns: Result with array of unsigned bytes (8 bits) set to TRUE(1) or FALSE(0).
    public func readBits(addr: Int32, count: Int32) -> Result<[UInt8], ModbusError> {
        var reply: [UInt8] = .init(repeating: 0, count: Int(count))
        guard modbus_read_bits(self.modbus, addr, count, &reply) != errorValue else {
            return .failure(modbusError())
        }
        return .success(reply)
    }
    
    /// Read the status of the input bits to the address of the remote device.
    /// The function uses the Modbus function code 0x02 (read input status).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the input bits
    /// - Returns: Result with array of unsigned bytes (8 bits) set to TRUE(1) or FALSE(0).
    public func readInputBits(addr: Int32, count: Int32) -> Result<[UInt8], ModbusError> {
        var reply: [UInt8] = .init(repeating: 0, count: Int(count))
        guard modbus_read_input_bits(self.modbus, addr, count, &reply) != errorValue else {
            return .failure(modbusError())
        }
        return .success(reply)
    }

    /// Read the content of the one holding register by address of the remote device.
    /// The function uses the Modbus function code 0x03 (read holding registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    /// - Returns: Result with register value as UInt16
    public func readRegister(addr: Int32) -> Result<UInt16, ModbusError> {
        var reply: UInt16 = 0
        guard modbus_read_registers(self.modbus, addr, 1, &reply) != errorValue else {
            return .failure(modbusError())
        }
        return .success(reply)
    }

    /// Read the content of the holding registers to the address of the remote device.
    /// The function uses the Modbus function code 0x03 (read holding registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the holding registers
    /// - Returns: Result with array as unsigned word values (16 bits).
    public func readRegisters(addr: Int32, count: Int32) -> Result<[UInt16], ModbusError> {
        var reply: [UInt16] = .init(repeating: 0, count: Int(count))
        guard modbus_read_registers(self.modbus, addr, count, &reply) != errorValue else {
            return .failure(modbusError())
        }
        return .success(reply)
    }
 
    /// Read the content of the input registers to the address of the remote device.
    /// The function uses the Modbus function code 0x04 (read input registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the input registers
    /// - Returns: Result with array as unsigned word values (16 bits).
    public func readInputRegisters(addr: Int32, count: Int32) -> Result<[UInt16], ModbusError> {
        var reply: [UInt16] = .init(repeating: 0, count: Int(count))
        guard modbus_read_input_registers(self.modbus, addr, count, &reply) != errorValue else {
            return .failure(modbusError())
        }
        return .success(reply)
    }
    
    /// Write the status at the address of the remote device.
    /// The function uses the Modbus function code 0x05 (force single coil).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - status: boolean status to write
    /// - Returns: Result<Void, ModbusError>
    public func writeBit(addr: Int32, status: Bool) -> Result<Void, ModbusError> {
        guard modbus_write_bit(self.modbus, addr, status ? 1:0) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }

    /// Write the status of the bits (coils) at the address of the remote device.
    /// The function uses the Modbus function code 0x0F (force multiple coils).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - status: array of statuses
    /// - Returns: Result<Void, ModbusError>
    public func writeBits(addr: Int32, status: [UInt8]) -> Result<Void, ModbusError> {
        var statusLocal = status
        guard modbus_write_bits(self.modbus, addr, Int32(statusLocal.count), &statusLocal) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }
    
    /// Write the value to the holding register at the address of the remote device.
    /// The function uses the Modbus function code 0x06 (preset single register).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - value: value of holding register
    /// - Returns: Result<Void, ModbusError>
    public func writeRegister(addr: Int32, value: UInt16) -> Result<Void, ModbusError> {
        guard modbus_write_register(self.modbus, addr, value) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }

    /// Write to holding registers at address of the remote device.
    /// The function uses the Modbus function code 0x10 (preset multiple registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - data: array of values to be writteb
    /// - Returns: Result<Void, ModbusError>
    public func writeRegisters(addr: Int32, data: [UInt16]) -> Result<Void, ModbusError> {
        var dataLocal = data
        guard modbus_write_registers(self.modbus, addr, Int32(dataLocal.count), &dataLocal) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }

    /// Modify the value of the holding register at the remote device using the algorithm:
    ///  new value = (current value AND 'and') OR ('or' AND (NOT 'and'))
    /// The function uses the Modbus function code 0x16 (mask single register).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - maskAND: and mask
    ///   - maskOR: or mask
    /// - Returns: Result<Void, ModbusError>
    public func maskWriteRegister(addr: Int32, maskAND: UInt16, maskOR: UInt16) -> Result<Void, ModbusError> {
        guard modbus_mask_write_register(self.modbus, addr, maskAND, maskOR) != errorValue else {
            return .failure(modbusError())
        }
        return .success(())
    }
    
    /// Write and read number of registers in a single transaction
    /// The function uses the Modbus function code 0x17 (write/read registers).
    /// - Parameters:
    ///   - writeAddr: address of the remote device to write
    ///   - data: data array to write
    ///   - readAddr: address of the remote device to read
    ///   - readCount: count of read data
    /// - Returns: Result with array as unsigned word values (16 bits).
    public func writeAndReadRegisters(writeAddr: Int32, data: [UInt16], readAddr: Int32, readCount: Int32) -> Result<[UInt16], ModbusError> {
        var reply: [UInt16] = .init(repeating: 0, count: Int(readCount))
        var localData = data
        guard modbus_write_and_read_registers(self.modbus, writeAddr, Int32(data.count), &localData, readAddr, readCount, &reply) != errorValue else {
            return .failure(modbusError())
        }
        return .success(reply)
    }

    private func modbusError() -> ModbusError {
        let errorString = String(utf8String: modbus_strerror(errno)) ?? ""
        return .init(message: errorString, errno: errno)
    }

    private func toTimerInterval(sec: UInt32, usec: UInt32) -> TimeInterval {
        return (Double(sec) + Double(usec) / 1_000_000)
    }

    private func toSecUSec(timeInterval: TimeInterval ) -> (sec: UInt32, usec: UInt32) {
        let (whole, fraction) = modf(timeInterval)
        let sec = UInt32(whole)
        let usec = UInt32(fraction * 1_000_000)
        return (sec, usec)
    }
}
