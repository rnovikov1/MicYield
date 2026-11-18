"""Finder layout, built without AppleScript or access to the user's Finder."""
import os

volume_name = "MicYield"
format = "UDZO"
compression_level = 9
filesystem = "HFS+"
files = [defines["app"]]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(defines["root"], "Resources", "MicYield.icns")
background = defines["background"]
window_rect = ((180, 180), (640, 360))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 96
text_size = 13
label_pos = "bottom"
icon_locations = {"MicYield.app": (165, 172), "Applications": (475, 172)}
# Do not set FinderInfo on the signed app: strict codesign rejects it.
