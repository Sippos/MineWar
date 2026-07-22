import re

with open("assets/sprites/world/terrain/bricks/Bedrock_Border.svg", "r") as f:
    border_svg = f.read()

# Extract inner contents of the border SVG
inner = re.search(r'<svg[^>]*>(.*?)</svg>', border_svg, re.DOTALL).group(1)

# Wrap it in a group scaled/clipped, or just draw it directly
new_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<rect width="64" height="64" fill="#11121c"/>
<g transform="scale(1, 0.40625)">
{inner}
</g>
<rect y="26" width="64" height="38" fill="#11121c"/>
</svg>
"""

with open("assets/sprites/world/terrain/front_walls/Unmineable_Brick-Front-Rework.svg", "w") as f:
    f.write(new_svg)
print("Updated SVG!")
