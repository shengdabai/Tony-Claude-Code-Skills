#!/usr/bin/env python3
"""
BLE GATT Server Example for Orbit Timer

This module demonstrates a BLE GATT server with:
- Custom service for timer control
- Read/Write characteristics
- Notify characteristics for real-time updates
- Connection parameter management

Platform: This example uses bluez/dbus (Linux)
For ESP32/RP2350, adapt the structure to NimBLE or similar BLE stack.

Service Structure:
  Timer Service (UUID: 12345678-1234-5678-1234-56789abcdef0)
  ├── State Characteristic (UUID: 12345678-1234-5678-1234-56789abcdef1)
  │   Properties: Read, Notify
  │   Value: JSON {"running": bool, "remaining": uint32}
  ├── Command Characteristic (UUID: 12345678-1234-5678-1234-56789abcdef2)
  │   Properties: Write
  │   Value: JSON {"action": "start"|"pause"|"reset", "duration": uint32}
  └── Battery Characteristic (standard UUID: 0x2A19)
      Properties: Read, Notify
      Value: uint8 (percentage)
"""

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import json
import logging
import struct
from typing import Dict, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# DBus paths and interfaces for BlueZ
BLUEZ_SERVICE = 'org.bluez'
GATT_MANAGER_IFACE = 'org.bluez.GattManager1'
DBUS_OM_IFACE = 'org.freedesktop.DBus.ObjectManager'
GATT_SERVICE_IFACE = 'org.bluez.GattService1'
GATT_CHRC_IFACE = 'org.bluez.GattCharacteristic1'
GATT_DESC_IFACE = 'org.bluez.GattDescriptor1'

# Custom UUIDs for Orbit Timer Service
TIMER_SERVICE_UUID = '12345678-1234-5678-1234-56789abcdef0'
STATE_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef1'
COMMAND_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef2'
BATTERY_CHAR_UUID = '00002a19-0000-1000-8000-00805f9b34fb'  # Standard battery UUID


class Application(dbus.service.Object):
    """DBus application for GATT services"""

    def __init__(self, bus):
        self.path = '/'
        self.services = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_service(self, service):
        self.services.append(service)

    @dbus.service.method(DBUS_OM_IFACE, out_signature='a{oa{sa{sv}}}')
    def GetManagedObjects(self):
        response = {}
        for service in self.services:
            response[service.get_path()] = service.get_properties()
            chrcs = service.get_characteristics()
            for chrc in chrcs:
                response[chrc.get_path()] = chrc.get_properties()
                descs = chrc.get_descriptors()
                for desc in descs:
                    response[desc.get_path()] = desc.get_properties()
        return response


class Service(dbus.service.Object):
    """GATT Service base class"""

    PATH_BASE = '/org/bluez/example/service'

    def __init__(self, bus, index, uuid, primary):
        self.path = self.PATH_BASE + str(index)
        self.bus = bus
        self.uuid = uuid
        self.primary = primary
        self.characteristics = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            GATT_SERVICE_IFACE: {
                'UUID': self.uuid,
                'Primary': self.primary,
                'Characteristics': dbus.Array(
                    self.get_characteristic_paths(),
                    signature='o'
                )
            }
        }

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_characteristic(self, characteristic):
        self.characteristics.append(characteristic)

    def get_characteristic_paths(self):
        result = []
        for chrc in self.characteristics:
            result.append(chrc.get_path())
        return result

    def get_characteristics(self):
        return self.characteristics

    @dbus.service.method(DBUS_OM_IFACE, out_signature='a{oa{sa{sv}}}')
    def GetManagedObjects(self):
        response = {}
        response[self.get_path()] = self.get_properties()
        for chrc in self.characteristics:
            response[chrc.get_path()] = chrc.get_properties()
            for desc in chrc.get_descriptors():
                response[desc.get_path()] = desc.get_properties()
        return response


class Characteristic(dbus.service.Object):
    """GATT Characteristic base class"""

    def __init__(self, bus, index, uuid, flags, service):
        self.path = service.path + '/char' + str(index)
        self.bus = bus
        self.uuid = uuid
        self.service = service
        self.flags = flags
        self.descriptors = []
        self.notifying = False
        dbus.service.Object.__init__(self, bus, self.path)

    def get_properties(self):
        return {
            GATT_CHRC_IFACE: {
                'Service': self.service.get_path(),
                'UUID': self.uuid,
                'Flags': self.flags,
                'Descriptors': dbus.Array(
                    self.get_descriptor_paths(),
                    signature='o'
                )
            }
        }

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_descriptor(self, descriptor):
        self.descriptors.append(descriptor)

    def get_descriptor_paths(self):
        result = []
        for desc in self.descriptors:
            result.append(desc.get_path())
        return result

    def get_descriptors(self):
        return self.descriptors

    @dbus.service.method(GATT_CHRC_IFACE, in_signature='a{sv}', out_signature='ay')
    def ReadValue(self, options):
        logger.warning(f'ReadValue not implemented for {self.uuid}')
        return []

    @dbus.service.method(GATT_CHRC_IFACE, in_signature='aya{sv}')
    def WriteValue(self, value, options):
        logger.warning(f'WriteValue not implemented for {self.uuid}')

    @dbus.service.method(GATT_CHRC_IFACE)
    def StartNotify(self):
        if self.notifying:
            return
        self.notifying = True
        logger.info(f'Notifications enabled for {self.uuid}')

    @dbus.service.method(GATT_CHRC_IFACE)
    def StopNotify(self):
        if not self.notifying:
            return
        self.notifying = False
        logger.info(f'Notifications disabled for {self.uuid}')

    def notify_value(self, value):
        """Send notification with new value"""
        if not self.notifying:
            return
        self.PropertiesChanged(
            GATT_CHRC_IFACE,
            {'Value': value},
            []
        )


class StateCharacteristic(Characteristic):
    """Timer state characteristic (Read, Notify)"""

    def __init__(self, bus, index, service):
        Characteristic.__init__(
            self, bus, index, STATE_CHAR_UUID,
            ['read', 'notify'],
            service
        )
        self.state = {"running": False, "remaining": 0}

    def ReadValue(self, options):
        """Return current timer state as JSON"""
        value = json.dumps(self.state).encode('utf-8')
        logger.info(f'State read: {self.state}')
        return dbus.Array(value, signature='y')

    def update_state(self, running: bool, remaining: int):
        """Update state and notify connected clients"""
        self.state = {"running": running, "remaining": remaining}
        value = json.dumps(self.state).encode('utf-8')
        self.notify_value(dbus.Array(value, signature='y'))
        logger.info(f'State updated: {self.state}')


class CommandCharacteristic(Characteristic):
    """Timer command characteristic (Write)"""

    def __init__(self, bus, index, service, state_char):
        Characteristic.__init__(
            self, bus, index, COMMAND_CHAR_UUID,
            ['write'],
            service
        )
        self.state_char = state_char

    def WriteValue(self, value, options):
        """Handle timer commands"""
        try:
            # Convert DBus byte array to string
            cmd_str = bytes(value).decode('utf-8')
            cmd = json.loads(cmd_str)

            action = cmd.get('action')
            duration = cmd.get('duration', 0)

            logger.info(f'Command received: {action}, duration: {duration}')

            # Handle commands (simplified - real implementation would interface with timer)
            if action == 'start':
                self.state_char.update_state(True, duration)
            elif action == 'pause':
                current_remaining = self.state_char.state['remaining']
                self.state_char.update_state(False, current_remaining)
            elif action == 'reset':
                self.state_char.update_state(False, 0)
            else:
                logger.warning(f'Unknown action: {action}')

        except Exception as e:
            logger.error(f'Error processing command: {e}')


class BatteryCharacteristic(Characteristic):
    """Battery level characteristic (Read, Notify)"""

    def __init__(self, bus, index, service):
        Characteristic.__init__(
            self, bus, index, BATTERY_CHAR_UUID,
            ['read', 'notify'],
            service
        )
        self.battery_level = 100  # Percentage

    def ReadValue(self, options):
        """Return battery level as uint8"""
        logger.info(f'Battery read: {self.battery_level}%')
        return dbus.Array([dbus.Byte(self.battery_level)], signature='y')

    def update_battery(self, level: int):
        """Update battery level and notify"""
        self.battery_level = max(0, min(100, level))
        self.notify_value(dbus.Array([dbus.Byte(self.battery_level)], signature='y'))
        logger.info(f'Battery updated: {self.battery_level}%')


class TimerService(Service):
    """Orbit Timer GATT Service"""

    def __init__(self, bus, index):
        Service.__init__(self, bus, index, TIMER_SERVICE_UUID, True)

        # Create characteristics
        self.state_char = StateCharacteristic(bus, 0, self)
        self.add_characteristic(self.state_char)

        self.command_char = CommandCharacteristic(bus, 1, self, self.state_char)
        self.add_characteristic(self.command_char)

        self.battery_char = BatteryCharacteristic(bus, 2, self)
        self.add_characteristic(self.battery_char)


def main():
    """Start BLE GATT server"""
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    bus = dbus.SystemBus()
    adapter_path = '/org/bluez/hci0'  # Default Bluetooth adapter

    # Create application
    app = Application(bus)

    # Add Timer service
    timer_service = TimerService(bus, 0)
    app.add_service(timer_service)

    # Register application
    manager = dbus.Interface(
        bus.get_object(BLUEZ_SERVICE, adapter_path),
        GATT_MANAGER_IFACE
    )

    logger.info('Registering GATT application...')
    manager.RegisterApplication(
        app.get_path(),
        {},
        reply_handler=lambda: logger.info('GATT application registered'),
        error_handler=lambda err: logger.error(f'Registration failed: {err}')
    )

    # Start main loop
    mainloop = GLib.MainLoop()
    logger.info('BLE GATT server running. Press Ctrl+C to quit.')

    # Example: Simulate timer countdown
    def timer_tick():
        state = timer_service.state_char.state
        if state['running'] and state['remaining'] > 0:
            timer_service.state_char.update_state(True, state['remaining'] - 1)
        return True  # Continue timer

    # Tick every second
    GLib.timeout_add_seconds(1, timer_tick)

    # Example: Simulate battery drain
    def battery_update():
        current = timer_service.battery_char.battery_level
        if current > 0:
            timer_service.battery_char.update_battery(current - 1)
        return True

    # Update battery every 10 seconds
    GLib.timeout_add_seconds(10, battery_update)

    try:
        mainloop.run()
    except KeyboardInterrupt:
        logger.info('Shutting down...')


if __name__ == '__main__':
    main()
