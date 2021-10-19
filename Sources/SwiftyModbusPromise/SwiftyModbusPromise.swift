//
//  SwiftyModbusPromise.swift
//  
//
//  Created by Dmitriy Borovikov on 13.08.2021.
//

import Foundation
import CModbus
import PromiseKit

fileprivate let errorValue: Int32 = -1

/// Libmodbus wrapper class with Promises
public class SwiftyModbusPromise {
    /// libmodbus error
    public enum ModbusError: Error {
        case error(message: String, errno: Int32)
    }
    
    /// DispatchQueue for modbus acync opetations
    public var modbusQueue = DispatchQueue(label: "in.ioshack.modbusQueue")
    
    private var modbus: OpaquePointer

    
    /// Create a SwiftyModbus class for TCP Protocol
    /// - Parameters:
    ///   - address: IP address or host name
    ///   - port: port number to connect to
    public init(address: String, port: Int32) {
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
    /// - Returns: Promise<Void>
    public func connect() -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_connect(self.modbus) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill_()
        }
        return promise
    }

    
    ///  Close the connection established
    /// - Returns: Guarantee<Void>
    public func disconnect() -> Guarantee<Void> {
        Guarantee.init { resolve in
            modbusQueue.async {
                modbus_close(self.modbus)
                resolve(())
            }
        }
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
    /// - Returns: Promise<Void>
    public func flush() -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_flush(self.modbus) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(())
        }
        return promise
    }
    
    /// Read the status of the bits (coils) to the address of the remote device.
    /// The function uses the Modbus function code 0x01 (read coil status).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the bits (coils)
    /// - Returns: Promise with array of unsigned bytes (8 bits) set to TRUE(1) or FALSE(0).
    public func readBits(addr: Int32, count: Int32) -> Promise<[UInt8]> {
        let (promise, seal) = Promise<[UInt8]>.pending()
        modbusQueue.async {
            var rezult: [UInt8] = .init(repeating: 0, count: Int(count))
            guard
                modbus_read_bits(self.modbus, addr, count, &rezult) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(rezult)
        }
        return promise
    }
    
    /// Read the status of the input bits to the address of the remote device.
    /// The function uses the Modbus function code 0x02 (read input status).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the input bits
    /// - Returns: Promise with array of unsigned bytes (8 bits) set to TRUE(1) or FALSE(0).
    public func readInputBits(addr: Int32, count: Int32) -> Promise<[UInt8]> {
        let (promise, seal) = Promise<[UInt8]>.pending()
        modbusQueue.async {
            var rezult: [UInt8] = .init(repeating: 0, count: Int(count))
            guard
                modbus_read_input_bits(self.modbus, addr, count, &rezult) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(rezult)
        }
        return promise
    }

    /// Read the content of the one holding register by address of the remote device.
    /// The function uses the Modbus function code 0x03 (read holding registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    /// - Returns: Promise with register value as UInt16
    public func readRegister(addr: Int32) -> Promise<UInt16> {
        let (promise, seal) = Promise<UInt16>.pending()
        modbusQueue.async {
            var rezult: UInt16 = 0
            guard
                modbus_read_registers(self.modbus, addr, 1, &rezult) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(rezult)
        }
        return promise
    }

    /// Read the content of the holding registers to the address of the remote device.
    /// The function uses the Modbus function code 0x03 (read holding registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the holding registers
    /// - Returns: Promise with array as unsigned word values (16 bits).
    public func readRegisters(addr: Int32, count: Int32) -> Promise<[UInt16]> {
        let (promise, seal) = Promise<[UInt16]>.pending()
        modbusQueue.async {
            var rezult: [UInt16] = .init(repeating: 0, count: Int(count))
            guard
                modbus_read_registers(self.modbus, addr, count, &rezult) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(rezult)
        }
        return promise
    }
 
    /// Read the content of the input registers to the address of the remote device.
    /// The function uses the Modbus function code 0x04 (read input registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - count: count of the input registers
    /// - Returns: Promise with array as unsigned word values (16 bits).
    public func readInputRegisters(addr: Int32, count: Int32) -> Promise<[UInt16]> {
        let (promise, seal) = Promise<[UInt16]>.pending()
        modbusQueue.async {
            var rezult: [UInt16] = .init(repeating: 0, count: Int(count))
            guard
                modbus_read_input_registers(self.modbus, addr, count, &rezult) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(rezult)
        }
        return promise
    }
    
    /// Write the status at the address of the remote device.
    /// The function uses the Modbus function code 0x05 (force single coil).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - status: boolean status to write
    /// - Returns: Promise<Void>
    public func writeBit(addr: Int32, status: Bool) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_write_bit(self.modbus, addr, status ? 1:0) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(())
        }
        return promise
    }

    /// Write the status of the bits (coils) at the address of the remote device.
    /// The function uses the Modbus function code 0x0F (force multiple coils).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - status: array of statuses
    /// - Returns: Promise<Void>
    public func writeBits(addr: Int32, status: [UInt8]) -> Promise<Void> {
        var statusLocal = status
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_write_bits(self.modbus, addr, Int32(statusLocal.count), &statusLocal) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(())
        }
        return promise
    }
    
    /// Write the value to the holding register at the address of the remote device.
    /// The function uses the Modbus function code 0x06 (preset single register).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - value: value of holding register
    /// - Returns: Promise<Void>
    public func writeRegister(addr: Int32, value: UInt16) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_write_register(self.modbus, addr, value) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(())
        }
        return promise
    }

    /// Write to holding registers at address of the remote device.
    /// The function uses the Modbus function code 0x10 (preset multiple registers).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - data: array of values to be writteb
    /// - Returns: Promise<Void>
    public func writeRegisters(addr: Int32, data: [UInt16]) -> Promise<Void> {
        var dataLocal = data
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_write_registers(self.modbus, addr, Int32(dataLocal.count), &dataLocal) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(())
        }
        return promise
    }

    
    /// Modify the value of the holding register at the remote device using the algorithm:
    ///  new value = (current value AND 'and') OR ('or' AND (NOT 'and'))
    /// The function uses the Modbus function code 0x16 (mask single register).
    /// - Parameters:
    ///   - addr: address of the remote device
    ///   - maskAND: and mask
    ///   - maskOR: or mask
    /// - Returns: Promise<Void>
    public func maskWriteRegister(addr: Int32, maskAND: UInt16, maskOR: UInt16) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        modbusQueue.async {
            guard
                modbus_mask_write_register(self.modbus, addr, maskAND, maskOR) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(())
        }
        return promise
    }
    
    /// Write and read number of registers in a single transaction
    /// - Parameters:
    ///   - writeAddr: address of the remote device to write
    ///   - data: data array to write
    ///   - readAddr: address of the remote device to read
    ///   - readCount: count of read data
    /// - Returns: Promise with array as unsigned word values (16 bits).
    public func writeAndReadRegisters(writeAddr: Int32, data: [UInt16], readAddr: Int32, readCount: Int32) -> Promise<[UInt16]> {
        let (promise, seal) = Promise<[UInt16]>.pending()
        modbusQueue.async {
            var rezult: [UInt16] = .init(repeating: 0, count: Int(readCount))
            var localData = data
            guard
                modbus_write_and_read_registers(self.modbus, writeAddr, Int32(data.count), &localData, readAddr, readCount, &rezult) != errorValue
            else {
                let error = self.modbusError(errno: errno)
                seal.reject(error)
                return
            }
            seal.fulfill(rezult)
        }
        return promise
    }

    private func modbusError(errno: Int32) -> ModbusError {
        let errorString = String(utf8String: modbus_strerror(errno)) ?? ""
        return .error(message: errorString, errno: errno)
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
