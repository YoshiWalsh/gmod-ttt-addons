For any servers still stubbornly sticking with FastDL instead of moving to Workshop.

This plugin allows for using FastDL to deliver associated files (such as models and materials) for maps that were
originally designed for Workshop. (Before Workshop, associated files were included within the map file using a
packer program. This is only necessary for Workshop maps.)

Currently includes support for ttt_waterworld, ttt_mc_downtown, and ttt_mc_stronghold. To add support for any other
maps, edit `lua/autorun/server/sv_mapdownloads.lua`.

All required files should be extracted from the Workshop file (using gmad) and then placed in your FastDL server's
garrysmod directory. E.g. `garrysmod/materials/dglz/dglz_plastic_blue.vmt`