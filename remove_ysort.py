import re

with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# Remove y_sort_enabled = true
content = content.replace("y_sort_enabled = true\n", "")

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Removed Y-Sorting from main.tscn")
