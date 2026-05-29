function orbit-setup
    # Quick project environment setup
    cd $ORBIT_ROOT

    # Check if Mosquitto is running
    if not systemctl is-active --quiet mosquitto
        echo "🚀 Starting Mosquitto MQTT broker..."
        sudo systemctl start mosquitto
    end

    echo "✅ Project environment ready!"
    echo "📍 Location: $(pwd)"
    echo "🔧 Pico SDK: $PICO_SDK_PATH"
    echo "📡 MQTT Broker: localhost:1883 (WebSocket: 9001)"
end
