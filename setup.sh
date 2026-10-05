#!/bin/bash

# Setup user david dan home directory
if ! id -u david >/dev/null 2>&1; then
    useradd -m -s /bin/bash david
fi

# Create flag4 di /home/david dengan permission 644
echo "UPRAK26{linux-enumeration-is-key-3f4a5b6c7d8e}" > /home/david/flag4.txt
chmod 644 /home/david/flag4.txt
chown david:david /home/david/flag4.txt

# Jalankan Apache
apache2-foreground
