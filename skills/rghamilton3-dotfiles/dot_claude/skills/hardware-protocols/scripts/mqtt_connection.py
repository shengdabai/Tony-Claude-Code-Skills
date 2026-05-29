#!/usr/bin/env python3
"""
MQTT Connection Handler with Robust Reconnection Logic

This module provides a production-ready MQTT client with:
- Exponential backoff reconnection strategy
- Message queuing during disconnections
- Connection state callbacks
- Persistent session support
- Last Will and Testament (LWT) configuration

Usage:
    client = RobustMQTTClient("orbit-device-001", "192.168.1.100")
    client.on_message_callback = handle_message
    client.connect()
    client.publish("orbit/device/status", '{"online": true}')
"""

import paho.mqtt.client as mqtt
import time
import json
import logging
from typing import Callable, Optional, Dict, Any
from collections import deque
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class QueuedMessage:
    """Message queued during disconnection"""
    topic: str
    payload: str
    qos: int = 1
    retain: bool = False


class RobustMQTTClient:
    """MQTT client with automatic reconnection and message queuing"""

    def __init__(
        self,
        client_id: str,
        broker_host: str,
        broker_port: int = 1883,
        keepalive: int = 60,
        clean_session: bool = False,
        websocket: bool = False,
        websocket_path: str = "/mqtt"
    ):
        """
        Initialize MQTT client with reconnection support.

        Args:
            client_id: Unique client identifier
            broker_host: MQTT broker hostname or IP
            broker_port: Broker port (1883 for TCP, 9001 for WebSocket)
            keepalive: Keep-alive interval in seconds
            clean_session: If True, discard subscriptions on disconnect
            websocket: Use WebSocket transport (for Stream Deck plugin)
            websocket_path: WebSocket path (default "/mqtt")
        """
        self.client_id = client_id
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.keepalive = keepalive
        self.websocket = websocket

        # Create MQTT client
        if websocket:
            self.client = mqtt.Client(
                client_id=client_id,
                clean_session=clean_session,
                transport="websockets"
            )
            self.client.ws_set_options(path=websocket_path)
        else:
            self.client = mqtt.Client(
                client_id=client_id,
                clean_session=clean_session
            )

        # Connection state
        self.connected = False
        self.reconnect_delay = 1  # Start with 1 second
        self.max_reconnect_delay = 60  # Max 60 seconds
        self.subscriptions: Dict[str, int] = {}  # topic -> qos

        # Message queue (limit to 100 messages to prevent memory issues)
        self.message_queue: deque[QueuedMessage] = deque(maxlen=100)

        # Callbacks
        self.on_connect_callback: Optional[Callable] = None
        self.on_disconnect_callback: Optional[Callable] = None
        self.on_message_callback: Optional[Callable[[str, str], None]] = None

        # Set up MQTT callbacks
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message

    def set_last_will(
        self,
        topic: str,
        payload: str,
        qos: int = 1,
        retain: bool = True
    ):
        """
        Configure Last Will and Testament.

        The broker will automatically publish this message if the client
        disconnects unexpectedly (without sending DISCONNECT).

        Args:
            topic: Topic to publish LWT message
            payload: LWT message content
            qos: QoS level (0, 1, or 2)
            retain: Whether to retain the LWT message
        """
        self.client.will_set(topic, payload, qos=qos, retain=retain)
        logger.info(f"Set LWT: {topic} = {payload}")

    def connect(self, blocking: bool = False):
        """
        Connect to MQTT broker.

        Args:
            blocking: If True, block until connected. If False, connect in background.
        """
        try:
            logger.info(
                f"Connecting to MQTT broker {self.broker_host}:{self.broker_port} "
                f"(WebSocket: {self.websocket})"
            )
            self.client.connect(
                self.broker_host,
                self.broker_port,
                self.keepalive
            )

            if blocking:
                self.client.loop_forever()
            else:
                self.client.loop_start()

        except Exception as e:
            logger.error(f"Connection failed: {e}")
            if not blocking:
                # Schedule reconnection
                self._schedule_reconnect()

    def disconnect(self):
        """Gracefully disconnect from broker"""
        logger.info("Disconnecting from MQTT broker")
        self.client.disconnect()
        self.client.loop_stop()

    def subscribe(self, topic: str, qos: int = 1):
        """
        Subscribe to topic with specified QoS.

        Subscriptions are automatically re-established on reconnection.

        Args:
            topic: Topic pattern to subscribe (supports wildcards)
            qos: Quality of Service level (0, 1, or 2)
        """
        self.subscriptions[topic] = qos
        if self.connected:
            self.client.subscribe(topic, qos)
            logger.info(f"Subscribed to {topic} (QoS {qos})")

    def publish(
        self,
        topic: str,
        payload: str,
        qos: int = 1,
        retain: bool = False
    ):
        """
        Publish message to topic.

        If not connected, message is queued for later delivery.

        Args:
            topic: Topic to publish to
            payload: Message content (string or JSON)
            qos: Quality of Service level (0, 1, or 2)
            retain: Whether to retain message on broker
        """
        if self.connected:
            result = self.client.publish(topic, payload, qos=qos, retain=retain)
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.debug(f"Published to {topic}: {payload}")
            else:
                logger.error(f"Publish failed: {mqtt.error_string(result.rc)}")
        else:
            # Queue message for later
            msg = QueuedMessage(topic, payload, qos, retain)
            self.message_queue.append(msg)
            logger.warning(
                f"Not connected, queued message ({len(self.message_queue)} in queue)"
            )

    def _on_connect(self, client, userdata, flags, rc):
        """Internal callback when connected to broker"""
        if rc == 0:
            self.connected = True
            self.reconnect_delay = 1  # Reset backoff
            logger.info("Connected to MQTT broker")

            # Re-subscribe to topics
            for topic, qos in self.subscriptions.items():
                client.subscribe(topic, qos)
                logger.info(f"Re-subscribed to {topic}")

            # Publish queued messages
            while self.message_queue:
                msg = self.message_queue.popleft()
                client.publish(msg.topic, msg.payload, msg.qos, msg.retain)
                logger.info(f"Published queued message to {msg.topic}")

            # Call user callback
            if self.on_connect_callback:
                self.on_connect_callback()

        else:
            logger.error(f"Connection failed: {mqtt.connack_string(rc)}")
            self._schedule_reconnect()

    def _on_disconnect(self, client, userdata, rc):
        """Internal callback when disconnected from broker"""
        self.connected = False

        if rc == 0:
            logger.info("Cleanly disconnected from broker")
        else:
            logger.warning(f"Unexpected disconnect: {mqtt.error_string(rc)}")
            self._schedule_reconnect()

        # Call user callback
        if self.on_disconnect_callback:
            self.on_disconnect_callback()

    def _on_message(self, client, userdata, msg):
        """Internal callback when message received"""
        payload = msg.payload.decode('utf-8')
        logger.debug(f"Received message on {msg.topic}: {payload}")

        # Call user callback
        if self.on_message_callback:
            self.on_message_callback(msg.topic, payload)

    def _schedule_reconnect(self):
        """Schedule reconnection with exponential backoff"""
        logger.info(f"Reconnecting in {self.reconnect_delay} seconds...")
        time.sleep(self.reconnect_delay)

        # Exponential backoff: 1s -> 2s -> 4s -> 8s -> ... -> 60s
        self.reconnect_delay = min(self.reconnect_delay * 2, self.max_reconnect_delay)

        try:
            self.client.reconnect()
        except Exception as e:
            logger.error(f"Reconnection failed: {e}")
            self._schedule_reconnect()


# Example usage
if __name__ == "__main__":
    def on_message(topic: str, payload: str):
        """Handle received messages"""
        print(f"Message received on {topic}: {payload}")

        # Parse JSON if applicable
        try:
            data = json.loads(payload)
            print(f"  Parsed: {data}")
        except json.JSONDecodeError:
            pass

    def on_connect():
        """Handle connection event"""
        print("Connected! Publishing online status...")
        client.publish(
            "orbit/device/example/status",
            json.dumps({"online": True, "timestamp": time.time()}),
            qos=1,
            retain=True
        )

    # Create client
    client = RobustMQTTClient(
        client_id="example-device",
        broker_host="192.168.1.100",  # Replace with your broker IP
        broker_port=1883,
        clean_session=False  # Use persistent session
    )

    # Configure Last Will (published if disconnected unexpectedly)
    client.set_last_will(
        "orbit/device/example/status",
        json.dumps({"online": False}),
        qos=1,
        retain=True
    )

    # Set callbacks
    client.on_connect_callback = on_connect
    client.on_message_callback = on_message

    # Subscribe to topics
    client.subscribe("orbit/timer/state/#", qos=1)
    client.subscribe("orbit/alert/visual/all", qos=1)

    # Connect (non-blocking)
    client.connect(blocking=False)

    # Publish some test messages
    try:
        while True:
            time.sleep(5)
            client.publish(
                "orbit/device/example/heartbeat",
                json.dumps({"timestamp": time.time()}),
                qos=0
            )

    except KeyboardInterrupt:
        print("\nDisconnecting...")
        client.disconnect()
