import re

with open("main.tscn", "r") as f:
    content = f.read()

# Remove y_sort_enabled = true
content = content.replace("y_sort_enabled = true\n", "")

with open("main.tscn", "w") as f:
    f.write(content)

print("Removed Y-Sorting from main.tscn")
