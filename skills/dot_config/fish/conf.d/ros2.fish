# Function to enter ROS2 Jazzy container
function jazzy
    distrobox enter jazzy -- fish -c '
        source /opt/ros/jazzy/setup.bash
        bass source /opt/ros/jazzy/setup.bash
        exec fish'
end

# Quick aliases for common ROS2 commands
abbr -a cb 'colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON'
abbr -a cbs 'colcon build --symlink-install --packages-select'
abbr -a ct 'colcon test'
abbr -a si 'source install/setup.bash'

# ROS2 domain ID (change for different robot projects)
set -gx ROS_DOMAIN_ID 42

# Colored output for ROS2 logs
set -gx RCUTILS_COLORIZED_OUTPUT 1
