function flash-device
    if test (count $argv) -lt 1
        echo "Usage: flash-device [presto|tembed]"
        return 1
    end

    switch $argv[1]
        case presto
            echo "📤 Flashing Presto (RP2350)..."
            cd $PROJECT_ROOT/src/presto/build
            picotool load presto_timer.uf2

        case tembed
            echo "📤 Flashing T-Embed (ESP32-S3)..."
            cd $PROJECT_ROOT/src/t-embed
            get_idf # Activate ESP-IDF
            pio run -t upload

        case '*'
            echo "❌ Unknown device: $argv[1]"
            echo "Available: presto, tembed"
            return 1
    end
end
